{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Handler.Hello where

import Import

getHelloR :: FooBARId -> Handler Html
getHelloR _fooBarId = do
    defaultLayout $ do
        setTitle "Hello Yesod!"
        $(widgetFile "hello")
