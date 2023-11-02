{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Handler.Hello where

import Import

getHelloR :: UserId -> Handler Html
getHelloR _userId = do
    defaultLayout $ do
        setTitle "Hello Yesod!"
        $(widgetFile "hello")
