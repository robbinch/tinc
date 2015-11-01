{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}
module Run where

import           Control.Exception
import           Development.GitRev
import           System.Environment.Compat
import           System.FileLock
import           System.FilePath
import           System.Process

import           Tinc.Install
import           Tinc.Setup
import           Tinc.Types

unsetEnvVars :: IO ()
unsetEnvVars = do
  unsetEnv "CABAL_SANDBOX_CONFIG"
  unsetEnv "CABAL_SANDBOX_PACKAGE_PATH"
  unsetEnv "GHC_PACKAGE_PATH"

tinc :: [String] -> IO ()
tinc args = do
  unsetEnvVars
  Facts{..} <- setup
  case args of
    [] -> withCacheLock factsCache $
      installDependencies factsGhcInfo False factsCache factsAddSourceCache
    ["--dry-run"] -> withCacheLock factsCache $
      installDependencies factsGhcInfo True factsCache factsAddSourceCache
    ["--version"] -> putStrLn $(gitHash)
    name : rest | Just plugin <- lookup name factsPlugins -> callPlugin plugin rest
    _ -> throwIO (ErrorCall $ "unrecognized arguments: " ++ show args)

callPlugin :: String -> [String] -> IO ()
callPlugin name args = do
  pid <- spawnProcess name args
  waitForProcess pid >>= throwIO

withCacheLock :: Path CacheDir -> IO a -> IO a
withCacheLock cache action = do
  putStrLn $ "Acquiring " ++ lock
  withFileLock lock Exclusive $ \ _ -> action
  where
    lock = path cache </> "tinc.lock"
