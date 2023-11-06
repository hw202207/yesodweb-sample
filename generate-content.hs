module Main where

import Data.List
import System.IO

main :: IO ()
main = do
  toFile "/tmp/poc-routers.txt" generateCtx1
  toFile "/tmp/poc-foundation.txt" generateCtx2
  toFile "/tmp/poc-handler.txt" generateCtx3
 where
  generateCtx1 index =
    "/hello" <> show index <> " Hello" <> show index <> "R GET"
  generateCtx2 index =
    "    isAuthorized Hello" <> show index <> "R _ = return Authorized"
  generateCtx3 index =
    intercalate
      "\n"
      [ "getHello" <> show index <> "R :: Handler Html"
      , "getHello" <> show index <> "R ="
      , "  defaultLayout $ do"
      , "    setTitle \"Hello" <> show index <> " Yesod\""
      , "    $(widgetFile \"hello\")"
      ]
  toFile fileName fn = do
    writeFile fileName ""
    appendFile fileName $ intercalate "\n" $ map fn [1 .. 5000]
