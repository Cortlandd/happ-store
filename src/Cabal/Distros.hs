{-# LANGUAGE
    OverloadedStrings
  , FlexibleContexts
  #-}

module Cabal.Distros where

import Cabal.Types
import Imports hiding (requestHeaders)

import Data.Aeson
import qualified Data.Text as T
import qualified Data.Text.Lazy as LT
import qualified Data.Text.Lazy.Encoding as LT
import qualified Data.ByteString.Lazy as LBS
import Network.HTTP.Client
import Data.HashMap.Strict as HM hiding (map, foldr, filter)
import Data.Char (isDigit)
import Data.Maybe (fromJust)
import Control.Monad.Catch
import Control.Monad.Reader

import GHC.Generics


type Distro = T.Text

fetchDistros :: MonadApp m => m (HashMap PackageName (HashMap Distro (Version, T.Text)))
fetchDistros = do
  manager  <- envManager <$> ask
  request  <- parseUrl "https://hackage.haskell.org/distros/"
  response <- liftIO $ httpLbs request manager
  let distros :: [LT.Text]
      distros = map LT.strip . LT.splitOn "," . LT.decodeUtf8 . responseBody $ response
  xs <- forM distros $ \d -> do
    request <- parseUrl $ "https://hackage.haskell.org/distro/"
                       ++ LT.unpack d ++ "/packages"
    response <- liftIO $ httpLbs request manager
    let fromLine :: LT.Text -> (PackageName, [(Distro, (Version, T.Text))])
        fromLine s = let [n,_,v,h] = LT.words s
                     in  ( LT.toStrict n
                         , [ ( LT.toStrict d
                             , ( fromJust . parseVersion . T.dropEnd 1 . LT.toStrict $ v
                               , LT.toStrict h
                               )
                             )
                           ]
                         )
    pure . fmap fromLine . drop 1 . LT.lines . LT.decodeUtf8 . responseBody $ response
  pure $ HM.fromList <$> foldr (uncurry $ HM.insertWith (++)) HM.empty (concat xs)
