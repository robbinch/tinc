{-# LANGUAGE CPP #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
module Tinc.Cache (
  Cache
, CachedPackage(..)
, readCache
, findReusablePackages
, cachedExecutables
, populateCache

#ifdef TEST
, PopulateCacheAction(..)
, populateCacheAction

, PackageLocation(..)
, readPackageGraph
, readAddSourceHashes
, addAddSourceHashes
, listSandboxes
#endif
) where

import           Control.Monad.Catch
import           Control.Monad
import           Control.Monad.IO.Class
import qualified Data.ByteString as B
import           Data.List
import qualified Data.Map as Map
import           Data.Yaml
import           System.Directory hiding (getDirectoryContents)
import           System.FilePath
import           System.IO.Temp
import           System.PosixCompat.Files
import           Data.Function

import           Tinc.Fail
import           Tinc.GhcInfo
import           Tinc.GhcPkg
import           Tinc.Package
import           Tinc.PackageGraph
import           Tinc.Process
import           Tinc.Sandbox
import           Tinc.AddSource
import           Tinc.Types
import           Util

data CachedPackage = CachedPackage {
  cachedPackageName :: Package
, cachedPackageConfig :: Path PackageConfig
} deriving (Eq, Show)

cachedExecutables :: CachedPackage -> IO [FilePath]
cachedExecutables (CachedPackage package (Path config)) = do
  exists <- doesDirectoryExist binDir
  if exists
    then listDirectoryContents binDir >>= mapM canonicalizePath
    else return []
  where
    binDir = dropFileName config </> ".." </> "bin" </> showPackage package

findReusablePackages :: Cache -> [Package] -> [CachedPackage]
findReusablePackages (Cache globalPackages packageGraphs) installPlan = reusablePackages
  where
    reusablePackages :: [CachedPackage]
    reusablePackages = nubBy ((==) `on` cachedPackageName) (concatMap findReusable packageGraphs)

    findReusable :: PackageGraph PackageLocation -> [CachedPackage]
    findReusable packageGraph =
      [CachedPackage p c | (p, PackageConfig c)  <- calculateReusablePackages packages packageGraph]
      where
        packages = nubBy ((==) `on` packageName) (installPlan ++ globalPackages)

data Cache = Cache {
  _cacheGlobalPackages :: [Package]
, _cachePackageGraphs :: [PackageGraph PackageLocation]
}

data PackageLocation = GlobalPackage | PackageConfig (Path PackageConfig)
  deriving (Eq, Ord, Show)

readPackageGraph :: (MonadIO m, Fail m, GhcPkg m) => [Package] -> Path PackageDb -> Path PackageDb -> m (PackageGraph PackageLocation)
readPackageGraph globalPackages globalPackageDb packageDb = do
  packageConfigs <- liftIO $ listPackages packageDb
  let globalValues = map (, GlobalPackage) globalPackages
  let values = map (fmap PackageConfig) packageConfigs
  dot <- readDotFile
  fromDot (globalValues ++ values) dot >>= liftIO . addAddSourceHashes packageDb
  where
    dotFile = path packageDb </> "packages.dot"
    readDotFile = do
      cachedIOAfter (liftIO $ touchPackageCache packageDb) dotFile $ do
        readGhcPkg [globalPackageDb, packageDb] ["dot"]

touchPackageCache :: Path PackageDb -> IO ()
touchPackageCache packageDb = touchFile (path packageDb </> "package.cache")

addSourceHashesFile :: FilePath
addSourceHashesFile = "add-source.yaml"

readAddSourceHashes :: Path PackageDb -> IO [AddSource]
readAddSourceHashes packageDb = do
  let file = path packageDb </> addSourceHashesFile
  exists <- doesFileExist file
  if exists
    then B.readFile file >>= either dieLoc return . decodeEither
    else return []

writeAddSourceHashes :: Path PackageDb -> [AddSource] -> IO ()
writeAddSourceHashes packageDb addSourceHashes
  | null addSourceHashes = return ()
  | otherwise = do
      encodeFile (path packageDb </> addSourceHashesFile) addSourceHashes
      touchPackageCache packageDb

addAddSourceHash :: Map.Map String String -> Package -> PackageLocation -> Package
addAddSourceHash hashes package location = case location of
  PackageConfig _ -> maybe package (\ hash -> setAddSourceHash hash package) (Map.lookup (packageName package) hashes)
  GlobalPackage -> package

addAddSourceHashes :: Path PackageDb -> PackageGraph PackageLocation -> IO (PackageGraph PackageLocation)
addAddSourceHashes packageDb graph = do
  hashes <- mkMap <$> readAddSourceHashes packageDb
  return $ mapIndex (addAddSourceHash hashes) graph
  where
    mkMap :: [AddSource] -> Map.Map String String
    mkMap hashes = Map.fromList (map (\ (AddSource name hash) -> (name, hash)) hashes)

readCache :: GhcInfo -> Path CacheDir -> IO Cache
readCache ghcInfo cacheDir = do
  globalPackages <- listGlobalPackages
  sandboxes <- listSandboxes cacheDir
  cache <- forM sandboxes $ \ sandbox -> do
    packageDbPath <- findPackageDb sandbox
    readPackageGraph globalPackages (ghcInfoGlobalPackageDb ghcInfo) packageDbPath
  return (Cache globalPackages cache)

validMarker :: FilePath
validMarker = "tinc.valid.v3"

listSandboxes :: Path CacheDir -> IO [Path Sandbox]
listSandboxes (Path cacheDir) = map Path <$> listEntries
  where
    isValidCacheEntry :: FilePath -> IO Bool
    isValidCacheEntry p = doesFileExist (p </> validMarker)

    listEntries :: IO [FilePath]
    listEntries = listDirectories cacheDir >>= filterM isValidCacheEntry

data PopulateCacheAction = PopulateCacheAction {
  populateCacheActionInstallPlan :: [Package]
, populateCacheActionAddSource :: [Path AddSource]
, populateCacheActionWriteAddSourceHashes :: [AddSource]
} deriving (Eq, Show)

populateCacheAction :: Path AddSourceCache -> [Package] -> [CachedPackage] -> Either [CachedPackage] PopulateCacheAction
populateCacheAction addSourceCache missing reusable
  | null missing = Left reusable
  | otherwise = Right PopulateCacheAction {
    populateCacheActionInstallPlan = installPlan
  , populateCacheActionAddSource = addSource
  , populateCacheActionWriteAddSourceHashes = [AddSource name hash | Package name (Version _ (Just hash)) <- (missing ++ map cachedPackageName reusable)]
  }
  where
    installPlan :: [Package]
    installPlan = missing ++ [p | p@(Package _ (Version _ Nothing)) <- map cachedPackageName reusable]

    addSource :: [Path AddSource]
    addSource = map (addSourcePath addSourceCache) [AddSource name hash | Package name (Version _ (Just hash)) <- missing]

populateCache :: (MonadIO m, MonadMask m, Fail m, MonadProcess m) => Path CacheDir -> Path AddSourceCache -> [Package] -> [CachedPackage] -> m [CachedPackage]
populateCache cacheDir addSourceCache missing reusable = either return populate (populateCacheAction addSourceCache missing reusable)
  where
    populate PopulateCacheAction{..} = do
      sandbox <- liftIO $ newCacheEntry cacheDir
      withCurrentDirectory sandbox $ do
        packageDb <- initSandbox populateCacheActionAddSource (map cachedPackageConfig reusable)
        liftIO $ do
          writeAddSourceHashes packageDb populateCacheActionWriteAddSourceHashes
          writeFile validMarker ""
        callProcessM "cabal" ("install" : "--bindir=$prefix/bin/$pkgid" : map showPackage populateCacheActionInstallPlan)
        map (uncurry CachedPackage) <$> listPackages packageDb

newCacheEntry :: Path CacheDir -> IO FilePath
newCacheEntry cacheDir = do
  basename <- takeBaseName <$> getCurrentDirectory
  createTempDirectory (path cacheDir) (basename ++ "-")
