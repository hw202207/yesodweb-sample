{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE ExplicitForAll #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE InstanceSigs, TypeOperators #-}

module Foundation where

import Import.NoFoundation
import Data.Kind            (Type)
import Database.Persist.Sql (ConnectionPool, runSqlPool)
import Text.Hamlet          (hamletFile)
import Text.Jasmine         (minifym)
import Control.Monad.Logger (LogSource)

-- Used only when in "auth-dummy-login" setting is enabled.
import Yesod.Auth.Dummy

import Yesod.Auth.OpenId    (authOpenId, IdentifierType (Claimed))
import Yesod.Default.Util   (addStaticContentExternal)
import Yesod.Core.Types     (Logger)
import qualified Yesod.Core.Unsafe as Unsafe
import qualified Data.CaseInsensitive as CI
import qualified Data.Text.Encoding as TE

-- | The foundation datatype for your application. This can be a good place to
-- keep settings and values requiring initialization before your application
-- starts running, such as database connections. Every handler will have
-- access to the data present here.
data App = App
    { appSettings    :: AppSettings
    , appStatic      :: Static -- ^ Settings for static file serving.
    , appConnPool    :: ConnectionPool -- ^ Database connection pool.
    , appHttpManager :: Manager
    , appLogger      :: Logger
    }

data MenuItem = MenuItem
    { menuItemLabel :: Text
    , menuItemRoute :: Route App
    , menuItemAccessCallback :: Bool
    }

data MenuTypes
    = NavbarLeft MenuItem
    | NavbarRight MenuItem

-- This is where we define all of the routes in our application. For a full
-- explanation of the syntax, please see:
-- http://www.yesodweb.com/book/routing-and-handlers
--
-- Note that this is really half the story; in Application.hs, mkYesodDispatch
-- generates the rest of the code. Please see the following documentation
-- for an explanation for this split:
-- http://www.yesodweb.com/book/scaffolding-and-the-site-template#scaffolding-and-the-site-template_foundation_and_application_modules
--
-- This function also generates the following type synonyms:
-- type Handler = HandlerFor App
-- type Widget = WidgetFor App ()
mkYesodData "App" $(parseRoutesFile "config/routes.yesodroutes")

-- | A convenient synonym for creating forms.
type Form x = Html -> MForm (HandlerFor App) (FormResult x, Widget)

-- | A convenient synonym for database access functions.
type DB a = forall (m :: Type -> Type).
    (MonadUnliftIO m) => ReaderT SqlBackend m a

-- Please see the documentation for the Yesod typeclass. There are a number
-- of settings which can be configured by overriding methods here.
instance Yesod App where
    -- Controls the base of generated URLs. For more information on modifying,
    -- see: https://github.com/yesodweb/yesod/wiki/Overriding-approot
    approot :: Approot App
    approot = ApprootRequest $ \app req ->
        case appRoot $ appSettings app of
            Nothing -> getApprootText guessApproot app req
            Just root -> root

    -- Store session data on the client in encrypted cookies,
    -- default session idle timeout is 120 minutes
    makeSessionBackend :: App -> IO (Maybe SessionBackend)
    makeSessionBackend _ = Just <$> defaultClientSessionBackend
        120    -- timeout in minutes
        "config/client_session_key.aes"

    -- Yesod Middleware allows you to run code before and after each handler function.
    -- The defaultYesodMiddleware adds the response header "Vary: Accept, Accept-Language" and performs authorization checks.
    -- Some users may also want to add the defaultCsrfMiddleware, which:
    --   a) Sets a cookie with a CSRF token in it.
    --   b) Validates that incoming write requests include that token in either a header or POST parameter.
    -- To add it, chain it together with the defaultMiddleware: yesodMiddleware = defaultYesodMiddleware . defaultCsrfMiddleware
    -- For details, see the CSRF documentation in the Yesod.Core.Handler module of the yesod-core package.
    yesodMiddleware :: ToTypedContent res => Handler res -> Handler res
    yesodMiddleware = defaultYesodMiddleware

    defaultLayout :: Widget -> Handler Html
    defaultLayout widget = do
        master <- getYesod
        mmsg <- getMessage

        muser <- maybeAuthPair
        mcurrentRoute <- getCurrentRoute

        -- Get the breadcrumbs, as defined in the YesodBreadcrumbs instance.
        (title, parents) <- breadcrumbs

        -- Define the menu items of the header.
        let menuItems =
                [ NavbarLeft $ MenuItem
                    { menuItemLabel = "Home"
                    , menuItemRoute = HomeR
                    , menuItemAccessCallback = True
                    }
                , NavbarLeft $ MenuItem
                    { menuItemLabel = "Profile"
                    , menuItemRoute = ProfileR
                    , menuItemAccessCallback = isJust muser
                    }
                , NavbarRight $ MenuItem
                    { menuItemLabel = "Login"
                    , menuItemRoute = AuthR LoginR
                    , menuItemAccessCallback = isNothing muser
                    }
                , NavbarRight $ MenuItem
                    { menuItemLabel = "Logout"
                    , menuItemRoute = AuthR LogoutR
                    , menuItemAccessCallback = isJust muser
                    }
                ]

        let navbarLeftMenuItems = [x | NavbarLeft x <- menuItems]
        let navbarRightMenuItems = [x | NavbarRight x <- menuItems]

        let navbarLeftFilteredMenuItems = [x | x <- navbarLeftMenuItems, menuItemAccessCallback x]
        let navbarRightFilteredMenuItems = [x | x <- navbarRightMenuItems, menuItemAccessCallback x]

        -- We break up the default layout into two components:
        -- default-layout is the contents of the body tag, and
        -- default-layout-wrapper is the entire page. Since the final
        -- value passed to hamletToRepHtml cannot be a widget, this allows
        -- you to use normal widget features in default-layout.

        pc <- widgetToPageContent $ do
            addStylesheet $ StaticR css_bootstrap_css
                                    -- ^ generated from @Settings/StaticFiles.hs@
            $(widgetFile "default-layout")
        withUrlRenderer $(hamletFile "templates/default-layout-wrapper.hamlet")

    -- The page to be redirected to when authentication is required.
    authRoute
        :: App
        -> Maybe (Route App)
    authRoute _ = Just $ AuthR LoginR

    isAuthorized
        :: Route App  -- ^ The route the user is visiting.
        -> Bool       -- ^ Whether or not this is a "write" request.
        -> Handler AuthResult
    -- Routes not requiring authentication.
    isAuthorized (AuthR _) _ = return Authorized
    isAuthorized (HelloR _) _ = return Authorized
    isAuthorized Hello1R _ = return Authorized
    isAuthorized Hello2R _ = return Authorized
    isAuthorized Hello3R _ = return Authorized
    isAuthorized Hello4R _ = return Authorized
    isAuthorized Hello5R _ = return Authorized
    isAuthorized Hello6R _ = return Authorized
    isAuthorized Hello7R _ = return Authorized
    isAuthorized Hello8R _ = return Authorized
    isAuthorized Hello9R _ = return Authorized
    isAuthorized Hello10R _ = return Authorized
    isAuthorized Hello11R _ = return Authorized
    isAuthorized Hello12R _ = return Authorized
    isAuthorized Hello13R _ = return Authorized
    isAuthorized Hello14R _ = return Authorized
    isAuthorized Hello15R _ = return Authorized
    isAuthorized Hello16R _ = return Authorized
    isAuthorized Hello17R _ = return Authorized
    isAuthorized Hello18R _ = return Authorized
    isAuthorized Hello19R _ = return Authorized
    isAuthorized Hello20R _ = return Authorized
    isAuthorized Hello21R _ = return Authorized
    isAuthorized Hello22R _ = return Authorized
    isAuthorized Hello23R _ = return Authorized
    isAuthorized Hello24R _ = return Authorized
    isAuthorized Hello25R _ = return Authorized
    isAuthorized Hello26R _ = return Authorized
    isAuthorized Hello27R _ = return Authorized
    isAuthorized Hello28R _ = return Authorized
    isAuthorized Hello29R _ = return Authorized
    isAuthorized Hello30R _ = return Authorized
    isAuthorized Hello31R _ = return Authorized
    isAuthorized Hello32R _ = return Authorized
    isAuthorized Hello33R _ = return Authorized
    isAuthorized Hello34R _ = return Authorized
    isAuthorized Hello35R _ = return Authorized
    isAuthorized Hello36R _ = return Authorized
    isAuthorized Hello37R _ = return Authorized
    isAuthorized Hello38R _ = return Authorized
    isAuthorized Hello39R _ = return Authorized
    isAuthorized Hello40R _ = return Authorized
    isAuthorized Hello41R _ = return Authorized
    isAuthorized Hello42R _ = return Authorized
    isAuthorized Hello43R _ = return Authorized
    isAuthorized Hello44R _ = return Authorized
    isAuthorized Hello45R _ = return Authorized
    isAuthorized Hello46R _ = return Authorized
    isAuthorized Hello47R _ = return Authorized
    isAuthorized Hello48R _ = return Authorized
    isAuthorized Hello49R _ = return Authorized
    isAuthorized Hello50R _ = return Authorized
    isAuthorized Hello51R _ = return Authorized
    isAuthorized Hello52R _ = return Authorized
    isAuthorized Hello53R _ = return Authorized
    isAuthorized Hello54R _ = return Authorized
    isAuthorized Hello55R _ = return Authorized
    isAuthorized Hello56R _ = return Authorized
    isAuthorized Hello57R _ = return Authorized
    isAuthorized Hello58R _ = return Authorized
    isAuthorized Hello59R _ = return Authorized
    isAuthorized Hello60R _ = return Authorized
    isAuthorized Hello61R _ = return Authorized
    isAuthorized Hello62R _ = return Authorized
    isAuthorized Hello63R _ = return Authorized
    isAuthorized Hello64R _ = return Authorized
    isAuthorized Hello65R _ = return Authorized
    isAuthorized Hello66R _ = return Authorized
    isAuthorized Hello67R _ = return Authorized
    isAuthorized Hello68R _ = return Authorized
    isAuthorized Hello69R _ = return Authorized
    isAuthorized Hello70R _ = return Authorized
    isAuthorized Hello71R _ = return Authorized
    isAuthorized Hello72R _ = return Authorized
    isAuthorized Hello73R _ = return Authorized
    isAuthorized Hello74R _ = return Authorized
    isAuthorized Hello75R _ = return Authorized
    isAuthorized Hello76R _ = return Authorized
    isAuthorized Hello77R _ = return Authorized
    isAuthorized Hello78R _ = return Authorized
    isAuthorized Hello79R _ = return Authorized
    isAuthorized Hello80R _ = return Authorized
    isAuthorized Hello81R _ = return Authorized
    isAuthorized Hello82R _ = return Authorized
    isAuthorized Hello83R _ = return Authorized
    isAuthorized Hello84R _ = return Authorized
    isAuthorized Hello85R _ = return Authorized
    isAuthorized Hello86R _ = return Authorized
    isAuthorized Hello87R _ = return Authorized
    isAuthorized Hello88R _ = return Authorized
    isAuthorized Hello89R _ = return Authorized
    isAuthorized Hello90R _ = return Authorized
    isAuthorized Hello91R _ = return Authorized
    isAuthorized Hello92R _ = return Authorized
    isAuthorized Hello93R _ = return Authorized
    isAuthorized Hello94R _ = return Authorized
    isAuthorized Hello95R _ = return Authorized
    isAuthorized Hello96R _ = return Authorized
    isAuthorized Hello97R _ = return Authorized
    isAuthorized Hello98R _ = return Authorized
    isAuthorized Hello99R _ = return Authorized
    isAuthorized Hello100R _ = return Authorized
    isAuthorized Hello101R _ = return Authorized
    isAuthorized Hello102R _ = return Authorized
    isAuthorized Hello103R _ = return Authorized
    isAuthorized Hello104R _ = return Authorized
    isAuthorized Hello105R _ = return Authorized
    isAuthorized Hello106R _ = return Authorized
    isAuthorized Hello107R _ = return Authorized
    isAuthorized Hello108R _ = return Authorized
    isAuthorized Hello109R _ = return Authorized
    isAuthorized Hello110R _ = return Authorized
    isAuthorized Hello111R _ = return Authorized
    isAuthorized Hello112R _ = return Authorized
    isAuthorized Hello113R _ = return Authorized
    isAuthorized Hello114R _ = return Authorized
    isAuthorized Hello115R _ = return Authorized
    isAuthorized Hello116R _ = return Authorized
    isAuthorized Hello117R _ = return Authorized
    isAuthorized Hello118R _ = return Authorized
    isAuthorized Hello119R _ = return Authorized
    isAuthorized Hello120R _ = return Authorized
    isAuthorized Hello121R _ = return Authorized
    isAuthorized Hello122R _ = return Authorized
    isAuthorized Hello123R _ = return Authorized
    isAuthorized Hello124R _ = return Authorized
    isAuthorized Hello125R _ = return Authorized
    isAuthorized Hello126R _ = return Authorized
    isAuthorized Hello127R _ = return Authorized
    isAuthorized Hello128R _ = return Authorized
    isAuthorized Hello129R _ = return Authorized
    isAuthorized Hello130R _ = return Authorized
    isAuthorized Hello131R _ = return Authorized
    isAuthorized Hello132R _ = return Authorized
    isAuthorized Hello133R _ = return Authorized
    isAuthorized Hello134R _ = return Authorized
    isAuthorized Hello135R _ = return Authorized
    isAuthorized Hello136R _ = return Authorized
    isAuthorized Hello137R _ = return Authorized
    isAuthorized Hello138R _ = return Authorized
    isAuthorized Hello139R _ = return Authorized
    isAuthorized Hello140R _ = return Authorized
    isAuthorized Hello141R _ = return Authorized
    isAuthorized Hello142R _ = return Authorized
    isAuthorized Hello143R _ = return Authorized
    isAuthorized Hello144R _ = return Authorized
    isAuthorized Hello145R _ = return Authorized
    isAuthorized Hello146R _ = return Authorized
    isAuthorized Hello147R _ = return Authorized
    isAuthorized Hello148R _ = return Authorized
    isAuthorized Hello149R _ = return Authorized
    isAuthorized Hello150R _ = return Authorized
    isAuthorized Hello151R _ = return Authorized
    isAuthorized Hello152R _ = return Authorized
    isAuthorized Hello153R _ = return Authorized
    isAuthorized Hello154R _ = return Authorized
    isAuthorized Hello155R _ = return Authorized
    isAuthorized Hello156R _ = return Authorized
    isAuthorized Hello157R _ = return Authorized
    isAuthorized Hello158R _ = return Authorized
    isAuthorized Hello159R _ = return Authorized
    isAuthorized Hello160R _ = return Authorized
    isAuthorized Hello161R _ = return Authorized
    isAuthorized Hello162R _ = return Authorized
    isAuthorized Hello163R _ = return Authorized
    isAuthorized Hello164R _ = return Authorized
    isAuthorized Hello165R _ = return Authorized
    isAuthorized Hello166R _ = return Authorized
    isAuthorized Hello167R _ = return Authorized
    isAuthorized Hello168R _ = return Authorized
    isAuthorized Hello169R _ = return Authorized
    isAuthorized Hello170R _ = return Authorized
    isAuthorized Hello171R _ = return Authorized
    isAuthorized Hello172R _ = return Authorized
    isAuthorized Hello173R _ = return Authorized
    isAuthorized Hello174R _ = return Authorized
    isAuthorized Hello175R _ = return Authorized
    isAuthorized Hello176R _ = return Authorized
    isAuthorized Hello177R _ = return Authorized
    isAuthorized Hello178R _ = return Authorized
    isAuthorized Hello179R _ = return Authorized
    isAuthorized Hello180R _ = return Authorized
    isAuthorized Hello181R _ = return Authorized
    isAuthorized Hello182R _ = return Authorized
    isAuthorized Hello183R _ = return Authorized
    isAuthorized Hello184R _ = return Authorized
    isAuthorized Hello185R _ = return Authorized
    isAuthorized Hello186R _ = return Authorized
    isAuthorized Hello187R _ = return Authorized
    isAuthorized Hello188R _ = return Authorized
    isAuthorized Hello189R _ = return Authorized
    isAuthorized Hello190R _ = return Authorized
    isAuthorized Hello191R _ = return Authorized
    isAuthorized Hello192R _ = return Authorized
    isAuthorized Hello193R _ = return Authorized
    isAuthorized Hello194R _ = return Authorized
    isAuthorized Hello195R _ = return Authorized
    isAuthorized Hello196R _ = return Authorized
    isAuthorized Hello197R _ = return Authorized
    isAuthorized Hello198R _ = return Authorized
    isAuthorized Hello199R _ = return Authorized
    isAuthorized Hello200R _ = return Authorized
    isAuthorized Hello201R _ = return Authorized
    isAuthorized Hello202R _ = return Authorized
    isAuthorized Hello203R _ = return Authorized
    isAuthorized Hello204R _ = return Authorized
    isAuthorized Hello205R _ = return Authorized
    isAuthorized Hello206R _ = return Authorized
    isAuthorized Hello207R _ = return Authorized
    isAuthorized Hello208R _ = return Authorized
    isAuthorized Hello209R _ = return Authorized
    isAuthorized Hello210R _ = return Authorized
    isAuthorized Hello211R _ = return Authorized
    isAuthorized Hello212R _ = return Authorized
    isAuthorized Hello213R _ = return Authorized
    isAuthorized Hello214R _ = return Authorized
    isAuthorized Hello215R _ = return Authorized
    isAuthorized Hello216R _ = return Authorized
    isAuthorized Hello217R _ = return Authorized
    isAuthorized Hello218R _ = return Authorized
    isAuthorized Hello219R _ = return Authorized
    isAuthorized Hello220R _ = return Authorized
    isAuthorized Hello221R _ = return Authorized
    isAuthorized Hello222R _ = return Authorized
    isAuthorized Hello223R _ = return Authorized
    isAuthorized Hello224R _ = return Authorized
    isAuthorized Hello225R _ = return Authorized
    isAuthorized Hello226R _ = return Authorized
    isAuthorized Hello227R _ = return Authorized
    isAuthorized Hello228R _ = return Authorized
    isAuthorized Hello229R _ = return Authorized
    isAuthorized Hello230R _ = return Authorized
    isAuthorized Hello231R _ = return Authorized
    isAuthorized Hello232R _ = return Authorized
    isAuthorized Hello233R _ = return Authorized
    isAuthorized Hello234R _ = return Authorized
    isAuthorized Hello235R _ = return Authorized
    isAuthorized Hello236R _ = return Authorized
    isAuthorized Hello237R _ = return Authorized
    isAuthorized Hello238R _ = return Authorized
    isAuthorized Hello239R _ = return Authorized
    isAuthorized Hello240R _ = return Authorized
    isAuthorized Hello241R _ = return Authorized
    isAuthorized Hello242R _ = return Authorized
    isAuthorized Hello243R _ = return Authorized
    isAuthorized Hello244R _ = return Authorized
    isAuthorized Hello245R _ = return Authorized
    isAuthorized Hello246R _ = return Authorized
    isAuthorized Hello247R _ = return Authorized
    isAuthorized Hello248R _ = return Authorized
    isAuthorized Hello249R _ = return Authorized
    isAuthorized Hello250R _ = return Authorized
    isAuthorized Hello251R _ = return Authorized
    isAuthorized Hello252R _ = return Authorized
    isAuthorized Hello253R _ = return Authorized
    isAuthorized Hello254R _ = return Authorized
    isAuthorized Hello255R _ = return Authorized
    isAuthorized Hello256R _ = return Authorized
    isAuthorized Hello257R _ = return Authorized
    isAuthorized Hello258R _ = return Authorized
    isAuthorized Hello259R _ = return Authorized
    isAuthorized Hello260R _ = return Authorized
    isAuthorized Hello261R _ = return Authorized
    isAuthorized Hello262R _ = return Authorized
    isAuthorized Hello263R _ = return Authorized
    isAuthorized Hello264R _ = return Authorized
    isAuthorized Hello265R _ = return Authorized
    isAuthorized Hello266R _ = return Authorized
    isAuthorized Hello267R _ = return Authorized
    isAuthorized Hello268R _ = return Authorized
    isAuthorized Hello269R _ = return Authorized
    isAuthorized Hello270R _ = return Authorized
    isAuthorized Hello271R _ = return Authorized
    isAuthorized Hello272R _ = return Authorized
    isAuthorized Hello273R _ = return Authorized
    isAuthorized Hello274R _ = return Authorized
    isAuthorized Hello275R _ = return Authorized
    isAuthorized Hello276R _ = return Authorized
    isAuthorized Hello277R _ = return Authorized
    isAuthorized Hello278R _ = return Authorized
    isAuthorized Hello279R _ = return Authorized
    isAuthorized Hello280R _ = return Authorized
    isAuthorized Hello281R _ = return Authorized
    isAuthorized Hello282R _ = return Authorized
    isAuthorized Hello283R _ = return Authorized
    isAuthorized Hello284R _ = return Authorized
    isAuthorized Hello285R _ = return Authorized
    isAuthorized Hello286R _ = return Authorized
    isAuthorized Hello287R _ = return Authorized
    isAuthorized Hello288R _ = return Authorized
    isAuthorized Hello289R _ = return Authorized
    isAuthorized Hello290R _ = return Authorized
    isAuthorized Hello291R _ = return Authorized
    isAuthorized Hello292R _ = return Authorized
    isAuthorized Hello293R _ = return Authorized
    isAuthorized Hello294R _ = return Authorized
    isAuthorized Hello295R _ = return Authorized
    isAuthorized Hello296R _ = return Authorized
    isAuthorized Hello297R _ = return Authorized
    isAuthorized Hello298R _ = return Authorized
    isAuthorized Hello299R _ = return Authorized
    isAuthorized Hello300R _ = return Authorized
    isAuthorized Hello301R _ = return Authorized
    isAuthorized Hello302R _ = return Authorized
    isAuthorized Hello303R _ = return Authorized
    isAuthorized Hello304R _ = return Authorized
    isAuthorized Hello305R _ = return Authorized
    isAuthorized Hello306R _ = return Authorized
    isAuthorized Hello307R _ = return Authorized
    isAuthorized Hello308R _ = return Authorized
    isAuthorized Hello309R _ = return Authorized
    isAuthorized Hello310R _ = return Authorized
    isAuthorized Hello311R _ = return Authorized
    isAuthorized Hello312R _ = return Authorized
    isAuthorized Hello313R _ = return Authorized
    isAuthorized Hello314R _ = return Authorized
    isAuthorized Hello315R _ = return Authorized
    isAuthorized Hello316R _ = return Authorized
    isAuthorized Hello317R _ = return Authorized
    isAuthorized Hello318R _ = return Authorized
    isAuthorized Hello319R _ = return Authorized
    isAuthorized Hello320R _ = return Authorized
    isAuthorized Hello321R _ = return Authorized
    isAuthorized Hello322R _ = return Authorized
    isAuthorized Hello323R _ = return Authorized
    isAuthorized Hello324R _ = return Authorized
    isAuthorized Hello325R _ = return Authorized
    isAuthorized Hello326R _ = return Authorized
    isAuthorized Hello327R _ = return Authorized
    isAuthorized Hello328R _ = return Authorized
    isAuthorized Hello329R _ = return Authorized
    isAuthorized Hello330R _ = return Authorized
    isAuthorized Hello331R _ = return Authorized
    isAuthorized Hello332R _ = return Authorized
    isAuthorized Hello333R _ = return Authorized
    isAuthorized Hello334R _ = return Authorized
    isAuthorized Hello335R _ = return Authorized
    isAuthorized Hello336R _ = return Authorized
    isAuthorized Hello337R _ = return Authorized
    isAuthorized Hello338R _ = return Authorized
    isAuthorized Hello339R _ = return Authorized
    isAuthorized Hello340R _ = return Authorized
    isAuthorized Hello341R _ = return Authorized
    isAuthorized Hello342R _ = return Authorized
    isAuthorized Hello343R _ = return Authorized
    isAuthorized Hello344R _ = return Authorized
    isAuthorized Hello345R _ = return Authorized
    isAuthorized Hello346R _ = return Authorized
    isAuthorized Hello347R _ = return Authorized
    isAuthorized Hello348R _ = return Authorized
    isAuthorized Hello349R _ = return Authorized
    isAuthorized Hello350R _ = return Authorized
    isAuthorized Hello351R _ = return Authorized
    isAuthorized Hello352R _ = return Authorized
    isAuthorized Hello353R _ = return Authorized
    isAuthorized Hello354R _ = return Authorized
    isAuthorized Hello355R _ = return Authorized
    isAuthorized Hello356R _ = return Authorized
    isAuthorized Hello357R _ = return Authorized
    isAuthorized Hello358R _ = return Authorized
    isAuthorized Hello359R _ = return Authorized
    isAuthorized Hello360R _ = return Authorized
    isAuthorized Hello361R _ = return Authorized
    isAuthorized Hello362R _ = return Authorized
    isAuthorized Hello363R _ = return Authorized
    isAuthorized Hello364R _ = return Authorized
    isAuthorized Hello365R _ = return Authorized
    isAuthorized Hello366R _ = return Authorized
    isAuthorized Hello367R _ = return Authorized
    isAuthorized Hello368R _ = return Authorized
    isAuthorized Hello369R _ = return Authorized
    isAuthorized Hello370R _ = return Authorized
    isAuthorized Hello371R _ = return Authorized
    isAuthorized Hello372R _ = return Authorized
    isAuthorized Hello373R _ = return Authorized
    isAuthorized Hello374R _ = return Authorized
    isAuthorized Hello375R _ = return Authorized
    isAuthorized Hello376R _ = return Authorized
    isAuthorized Hello377R _ = return Authorized
    isAuthorized Hello378R _ = return Authorized
    isAuthorized Hello379R _ = return Authorized
    isAuthorized Hello380R _ = return Authorized
    isAuthorized Hello381R _ = return Authorized
    isAuthorized Hello382R _ = return Authorized
    isAuthorized Hello383R _ = return Authorized
    isAuthorized Hello384R _ = return Authorized
    isAuthorized Hello385R _ = return Authorized
    isAuthorized Hello386R _ = return Authorized
    isAuthorized Hello387R _ = return Authorized
    isAuthorized Hello388R _ = return Authorized
    isAuthorized Hello389R _ = return Authorized
    isAuthorized Hello390R _ = return Authorized
    isAuthorized Hello391R _ = return Authorized
    isAuthorized Hello392R _ = return Authorized
    isAuthorized Hello393R _ = return Authorized
    isAuthorized Hello394R _ = return Authorized
    isAuthorized Hello395R _ = return Authorized
    isAuthorized Hello396R _ = return Authorized
    isAuthorized Hello397R _ = return Authorized
    isAuthorized Hello398R _ = return Authorized
    isAuthorized Hello399R _ = return Authorized
    isAuthorized Hello400R _ = return Authorized
    isAuthorized Hello401R _ = return Authorized
    isAuthorized Hello402R _ = return Authorized
    isAuthorized Hello403R _ = return Authorized
    isAuthorized Hello404R _ = return Authorized
    isAuthorized Hello405R _ = return Authorized
    isAuthorized Hello406R _ = return Authorized
    isAuthorized Hello407R _ = return Authorized
    isAuthorized Hello408R _ = return Authorized
    isAuthorized Hello409R _ = return Authorized
    isAuthorized Hello410R _ = return Authorized
    isAuthorized Hello411R _ = return Authorized
    isAuthorized Hello412R _ = return Authorized
    isAuthorized Hello413R _ = return Authorized
    isAuthorized Hello414R _ = return Authorized
    isAuthorized Hello415R _ = return Authorized
    isAuthorized Hello416R _ = return Authorized
    isAuthorized Hello417R _ = return Authorized
    isAuthorized Hello418R _ = return Authorized
    isAuthorized Hello419R _ = return Authorized
    isAuthorized Hello420R _ = return Authorized
    isAuthorized Hello421R _ = return Authorized
    isAuthorized Hello422R _ = return Authorized
    isAuthorized Hello423R _ = return Authorized
    isAuthorized Hello424R _ = return Authorized
    isAuthorized Hello425R _ = return Authorized
    isAuthorized Hello426R _ = return Authorized
    isAuthorized Hello427R _ = return Authorized
    isAuthorized Hello428R _ = return Authorized
    isAuthorized Hello429R _ = return Authorized
    isAuthorized Hello430R _ = return Authorized
    isAuthorized Hello431R _ = return Authorized
    isAuthorized Hello432R _ = return Authorized
    isAuthorized Hello433R _ = return Authorized
    isAuthorized Hello434R _ = return Authorized
    isAuthorized Hello435R _ = return Authorized
    isAuthorized Hello436R _ = return Authorized
    isAuthorized Hello437R _ = return Authorized
    isAuthorized Hello438R _ = return Authorized
    isAuthorized Hello439R _ = return Authorized
    isAuthorized Hello440R _ = return Authorized
    isAuthorized Hello441R _ = return Authorized
    isAuthorized Hello442R _ = return Authorized
    isAuthorized Hello443R _ = return Authorized
    isAuthorized Hello444R _ = return Authorized
    isAuthorized Hello445R _ = return Authorized
    isAuthorized Hello446R _ = return Authorized
    isAuthorized Hello447R _ = return Authorized
    isAuthorized Hello448R _ = return Authorized
    isAuthorized Hello449R _ = return Authorized
    isAuthorized Hello450R _ = return Authorized
    isAuthorized Hello451R _ = return Authorized
    isAuthorized Hello452R _ = return Authorized
    isAuthorized Hello453R _ = return Authorized
    isAuthorized Hello454R _ = return Authorized
    isAuthorized Hello455R _ = return Authorized
    isAuthorized Hello456R _ = return Authorized
    isAuthorized Hello457R _ = return Authorized
    isAuthorized Hello458R _ = return Authorized
    isAuthorized Hello459R _ = return Authorized
    isAuthorized Hello460R _ = return Authorized
    isAuthorized Hello461R _ = return Authorized
    isAuthorized Hello462R _ = return Authorized
    isAuthorized Hello463R _ = return Authorized
    isAuthorized Hello464R _ = return Authorized
    isAuthorized Hello465R _ = return Authorized
    isAuthorized Hello466R _ = return Authorized
    isAuthorized Hello467R _ = return Authorized
    isAuthorized Hello468R _ = return Authorized
    isAuthorized Hello469R _ = return Authorized
    isAuthorized Hello470R _ = return Authorized
    isAuthorized Hello471R _ = return Authorized
    isAuthorized Hello472R _ = return Authorized
    isAuthorized Hello473R _ = return Authorized
    isAuthorized Hello474R _ = return Authorized
    isAuthorized Hello475R _ = return Authorized
    isAuthorized Hello476R _ = return Authorized
    isAuthorized Hello477R _ = return Authorized
    isAuthorized Hello478R _ = return Authorized
    isAuthorized Hello479R _ = return Authorized
    isAuthorized Hello480R _ = return Authorized
    isAuthorized Hello481R _ = return Authorized
    isAuthorized Hello482R _ = return Authorized
    isAuthorized Hello483R _ = return Authorized
    isAuthorized Hello484R _ = return Authorized
    isAuthorized Hello485R _ = return Authorized
    isAuthorized Hello486R _ = return Authorized
    isAuthorized Hello487R _ = return Authorized
    isAuthorized Hello488R _ = return Authorized
    isAuthorized Hello489R _ = return Authorized
    isAuthorized Hello490R _ = return Authorized
    isAuthorized Hello491R _ = return Authorized
    isAuthorized Hello492R _ = return Authorized
    isAuthorized Hello493R _ = return Authorized
    isAuthorized Hello494R _ = return Authorized
    isAuthorized Hello495R _ = return Authorized
    isAuthorized Hello496R _ = return Authorized
    isAuthorized Hello497R _ = return Authorized
    isAuthorized Hello498R _ = return Authorized
    isAuthorized Hello499R _ = return Authorized
    isAuthorized Hello500R _ = return Authorized
    isAuthorized Hello501R _ = return Authorized
    isAuthorized Hello502R _ = return Authorized
    isAuthorized Hello503R _ = return Authorized
    isAuthorized Hello504R _ = return Authorized
    isAuthorized Hello505R _ = return Authorized
    isAuthorized Hello506R _ = return Authorized
    isAuthorized Hello507R _ = return Authorized
    isAuthorized Hello508R _ = return Authorized
    isAuthorized Hello509R _ = return Authorized
    isAuthorized Hello510R _ = return Authorized
    isAuthorized Hello511R _ = return Authorized
    isAuthorized Hello512R _ = return Authorized
    isAuthorized Hello513R _ = return Authorized
    isAuthorized Hello514R _ = return Authorized
    isAuthorized Hello515R _ = return Authorized
    isAuthorized Hello516R _ = return Authorized
    isAuthorized Hello517R _ = return Authorized
    isAuthorized Hello518R _ = return Authorized
    isAuthorized Hello519R _ = return Authorized
    isAuthorized Hello520R _ = return Authorized
    isAuthorized Hello521R _ = return Authorized
    isAuthorized Hello522R _ = return Authorized
    isAuthorized Hello523R _ = return Authorized
    isAuthorized Hello524R _ = return Authorized
    isAuthorized Hello525R _ = return Authorized
    isAuthorized Hello526R _ = return Authorized
    isAuthorized Hello527R _ = return Authorized
    isAuthorized Hello528R _ = return Authorized
    isAuthorized Hello529R _ = return Authorized
    isAuthorized Hello530R _ = return Authorized
    isAuthorized Hello531R _ = return Authorized
    isAuthorized Hello532R _ = return Authorized
    isAuthorized Hello533R _ = return Authorized
    isAuthorized Hello534R _ = return Authorized
    isAuthorized Hello535R _ = return Authorized
    isAuthorized Hello536R _ = return Authorized
    isAuthorized Hello537R _ = return Authorized
    isAuthorized Hello538R _ = return Authorized
    isAuthorized Hello539R _ = return Authorized
    isAuthorized Hello540R _ = return Authorized
    isAuthorized Hello541R _ = return Authorized
    isAuthorized Hello542R _ = return Authorized
    isAuthorized Hello543R _ = return Authorized
    isAuthorized Hello544R _ = return Authorized
    isAuthorized Hello545R _ = return Authorized
    isAuthorized Hello546R _ = return Authorized
    isAuthorized Hello547R _ = return Authorized
    isAuthorized Hello548R _ = return Authorized
    isAuthorized Hello549R _ = return Authorized
    isAuthorized Hello550R _ = return Authorized
    isAuthorized Hello551R _ = return Authorized
    isAuthorized Hello552R _ = return Authorized
    isAuthorized Hello553R _ = return Authorized
    isAuthorized Hello554R _ = return Authorized
    isAuthorized Hello555R _ = return Authorized
    isAuthorized Hello556R _ = return Authorized
    isAuthorized Hello557R _ = return Authorized
    isAuthorized Hello558R _ = return Authorized
    isAuthorized Hello559R _ = return Authorized
    isAuthorized Hello560R _ = return Authorized
    isAuthorized Hello561R _ = return Authorized
    isAuthorized Hello562R _ = return Authorized
    isAuthorized Hello563R _ = return Authorized
    isAuthorized Hello564R _ = return Authorized
    isAuthorized Hello565R _ = return Authorized
    isAuthorized Hello566R _ = return Authorized
    isAuthorized Hello567R _ = return Authorized
    isAuthorized Hello568R _ = return Authorized
    isAuthorized Hello569R _ = return Authorized
    isAuthorized Hello570R _ = return Authorized
    isAuthorized Hello571R _ = return Authorized
    isAuthorized Hello572R _ = return Authorized
    isAuthorized Hello573R _ = return Authorized
    isAuthorized Hello574R _ = return Authorized
    isAuthorized Hello575R _ = return Authorized
    isAuthorized Hello576R _ = return Authorized
    isAuthorized Hello577R _ = return Authorized
    isAuthorized Hello578R _ = return Authorized
    isAuthorized Hello579R _ = return Authorized
    isAuthorized Hello580R _ = return Authorized
    isAuthorized Hello581R _ = return Authorized
    isAuthorized Hello582R _ = return Authorized
    isAuthorized Hello583R _ = return Authorized
    isAuthorized Hello584R _ = return Authorized
    isAuthorized Hello585R _ = return Authorized
    isAuthorized Hello586R _ = return Authorized
    isAuthorized Hello587R _ = return Authorized
    isAuthorized Hello588R _ = return Authorized
    isAuthorized Hello589R _ = return Authorized
    isAuthorized Hello590R _ = return Authorized
    isAuthorized Hello591R _ = return Authorized
    isAuthorized Hello592R _ = return Authorized
    isAuthorized Hello593R _ = return Authorized
    isAuthorized Hello594R _ = return Authorized
    isAuthorized Hello595R _ = return Authorized
    isAuthorized Hello596R _ = return Authorized
    isAuthorized Hello597R _ = return Authorized
    isAuthorized Hello598R _ = return Authorized
    isAuthorized Hello599R _ = return Authorized
    isAuthorized Hello600R _ = return Authorized
    isAuthorized Hello601R _ = return Authorized
    isAuthorized Hello602R _ = return Authorized
    isAuthorized Hello603R _ = return Authorized
    isAuthorized Hello604R _ = return Authorized
    isAuthorized Hello605R _ = return Authorized
    isAuthorized Hello606R _ = return Authorized
    isAuthorized Hello607R _ = return Authorized
    isAuthorized Hello608R _ = return Authorized
    isAuthorized Hello609R _ = return Authorized
    isAuthorized Hello610R _ = return Authorized
    isAuthorized Hello611R _ = return Authorized
    isAuthorized Hello612R _ = return Authorized
    isAuthorized Hello613R _ = return Authorized
    isAuthorized Hello614R _ = return Authorized
    isAuthorized Hello615R _ = return Authorized
    isAuthorized Hello616R _ = return Authorized
    isAuthorized Hello617R _ = return Authorized
    isAuthorized Hello618R _ = return Authorized
    isAuthorized Hello619R _ = return Authorized
    isAuthorized Hello620R _ = return Authorized
    isAuthorized Hello621R _ = return Authorized
    isAuthorized Hello622R _ = return Authorized
    isAuthorized Hello623R _ = return Authorized
    isAuthorized Hello624R _ = return Authorized
    isAuthorized Hello625R _ = return Authorized
    isAuthorized Hello626R _ = return Authorized
    isAuthorized Hello627R _ = return Authorized
    isAuthorized Hello628R _ = return Authorized
    isAuthorized Hello629R _ = return Authorized
    isAuthorized Hello630R _ = return Authorized
    isAuthorized Hello631R _ = return Authorized
    isAuthorized Hello632R _ = return Authorized
    isAuthorized Hello633R _ = return Authorized
    isAuthorized Hello634R _ = return Authorized
    isAuthorized Hello635R _ = return Authorized
    isAuthorized Hello636R _ = return Authorized
    isAuthorized Hello637R _ = return Authorized
    isAuthorized Hello638R _ = return Authorized
    isAuthorized Hello639R _ = return Authorized
    isAuthorized Hello640R _ = return Authorized
    isAuthorized Hello641R _ = return Authorized
    isAuthorized Hello642R _ = return Authorized
    isAuthorized Hello643R _ = return Authorized
    isAuthorized Hello644R _ = return Authorized
    isAuthorized Hello645R _ = return Authorized
    isAuthorized Hello646R _ = return Authorized
    isAuthorized Hello647R _ = return Authorized
    isAuthorized Hello648R _ = return Authorized
    isAuthorized Hello649R _ = return Authorized
    isAuthorized Hello650R _ = return Authorized
    isAuthorized Hello651R _ = return Authorized
    isAuthorized Hello652R _ = return Authorized
    isAuthorized Hello653R _ = return Authorized
    isAuthorized Hello654R _ = return Authorized
    isAuthorized Hello655R _ = return Authorized
    isAuthorized Hello656R _ = return Authorized
    isAuthorized Hello657R _ = return Authorized
    isAuthorized Hello658R _ = return Authorized
    isAuthorized Hello659R _ = return Authorized
    isAuthorized Hello660R _ = return Authorized
    isAuthorized Hello661R _ = return Authorized
    isAuthorized Hello662R _ = return Authorized
    isAuthorized Hello663R _ = return Authorized
    isAuthorized Hello664R _ = return Authorized
    isAuthorized Hello665R _ = return Authorized
    isAuthorized Hello666R _ = return Authorized
    isAuthorized Hello667R _ = return Authorized
    isAuthorized Hello668R _ = return Authorized
    isAuthorized Hello669R _ = return Authorized
    isAuthorized Hello670R _ = return Authorized
    isAuthorized Hello671R _ = return Authorized
    isAuthorized Hello672R _ = return Authorized
    isAuthorized Hello673R _ = return Authorized
    isAuthorized Hello674R _ = return Authorized
    isAuthorized Hello675R _ = return Authorized
    isAuthorized Hello676R _ = return Authorized
    isAuthorized Hello677R _ = return Authorized
    isAuthorized Hello678R _ = return Authorized
    isAuthorized Hello679R _ = return Authorized
    isAuthorized Hello680R _ = return Authorized
    isAuthorized Hello681R _ = return Authorized
    isAuthorized Hello682R _ = return Authorized
    isAuthorized Hello683R _ = return Authorized
    isAuthorized Hello684R _ = return Authorized
    isAuthorized Hello685R _ = return Authorized
    isAuthorized Hello686R _ = return Authorized
    isAuthorized Hello687R _ = return Authorized
    isAuthorized Hello688R _ = return Authorized
    isAuthorized Hello689R _ = return Authorized
    isAuthorized Hello690R _ = return Authorized
    isAuthorized Hello691R _ = return Authorized
    isAuthorized Hello692R _ = return Authorized
    isAuthorized Hello693R _ = return Authorized
    isAuthorized Hello694R _ = return Authorized
    isAuthorized Hello695R _ = return Authorized
    isAuthorized Hello696R _ = return Authorized
    isAuthorized Hello697R _ = return Authorized
    isAuthorized Hello698R _ = return Authorized
    isAuthorized Hello699R _ = return Authorized
    isAuthorized Hello700R _ = return Authorized
    isAuthorized Hello701R _ = return Authorized
    isAuthorized Hello702R _ = return Authorized
    isAuthorized Hello703R _ = return Authorized
    isAuthorized Hello704R _ = return Authorized
    isAuthorized Hello705R _ = return Authorized
    isAuthorized Hello706R _ = return Authorized
    isAuthorized Hello707R _ = return Authorized
    isAuthorized Hello708R _ = return Authorized
    isAuthorized Hello709R _ = return Authorized
    isAuthorized Hello710R _ = return Authorized
    isAuthorized Hello711R _ = return Authorized
    isAuthorized Hello712R _ = return Authorized
    isAuthorized Hello713R _ = return Authorized
    isAuthorized Hello714R _ = return Authorized
    isAuthorized Hello715R _ = return Authorized
    isAuthorized Hello716R _ = return Authorized
    isAuthorized Hello717R _ = return Authorized
    isAuthorized Hello718R _ = return Authorized
    isAuthorized Hello719R _ = return Authorized
    isAuthorized Hello720R _ = return Authorized
    isAuthorized Hello721R _ = return Authorized
    isAuthorized Hello722R _ = return Authorized
    isAuthorized Hello723R _ = return Authorized
    isAuthorized Hello724R _ = return Authorized
    isAuthorized Hello725R _ = return Authorized
    isAuthorized Hello726R _ = return Authorized
    isAuthorized Hello727R _ = return Authorized
    isAuthorized Hello728R _ = return Authorized
    isAuthorized Hello729R _ = return Authorized
    isAuthorized Hello730R _ = return Authorized
    isAuthorized Hello731R _ = return Authorized
    isAuthorized Hello732R _ = return Authorized
    isAuthorized Hello733R _ = return Authorized
    isAuthorized Hello734R _ = return Authorized
    isAuthorized Hello735R _ = return Authorized
    isAuthorized Hello736R _ = return Authorized
    isAuthorized Hello737R _ = return Authorized
    isAuthorized Hello738R _ = return Authorized
    isAuthorized Hello739R _ = return Authorized
    isAuthorized Hello740R _ = return Authorized
    isAuthorized Hello741R _ = return Authorized
    isAuthorized Hello742R _ = return Authorized
    isAuthorized Hello743R _ = return Authorized
    isAuthorized Hello744R _ = return Authorized
    isAuthorized Hello745R _ = return Authorized
    isAuthorized Hello746R _ = return Authorized
    isAuthorized Hello747R _ = return Authorized
    isAuthorized Hello748R _ = return Authorized
    isAuthorized Hello749R _ = return Authorized
    isAuthorized Hello750R _ = return Authorized
    isAuthorized Hello751R _ = return Authorized
    isAuthorized Hello752R _ = return Authorized
    isAuthorized Hello753R _ = return Authorized
    isAuthorized Hello754R _ = return Authorized
    isAuthorized Hello755R _ = return Authorized
    isAuthorized Hello756R _ = return Authorized
    isAuthorized Hello757R _ = return Authorized
    isAuthorized Hello758R _ = return Authorized
    isAuthorized Hello759R _ = return Authorized
    isAuthorized Hello760R _ = return Authorized
    isAuthorized Hello761R _ = return Authorized
    isAuthorized Hello762R _ = return Authorized
    isAuthorized Hello763R _ = return Authorized
    isAuthorized Hello764R _ = return Authorized
    isAuthorized Hello765R _ = return Authorized
    isAuthorized Hello766R _ = return Authorized
    isAuthorized Hello767R _ = return Authorized
    isAuthorized Hello768R _ = return Authorized
    isAuthorized Hello769R _ = return Authorized
    isAuthorized Hello770R _ = return Authorized
    isAuthorized Hello771R _ = return Authorized
    isAuthorized Hello772R _ = return Authorized
    isAuthorized Hello773R _ = return Authorized
    isAuthorized Hello774R _ = return Authorized
    isAuthorized Hello775R _ = return Authorized
    isAuthorized Hello776R _ = return Authorized
    isAuthorized Hello777R _ = return Authorized
    isAuthorized Hello778R _ = return Authorized
    isAuthorized Hello779R _ = return Authorized
    isAuthorized Hello780R _ = return Authorized
    isAuthorized Hello781R _ = return Authorized
    isAuthorized Hello782R _ = return Authorized
    isAuthorized Hello783R _ = return Authorized
    isAuthorized Hello784R _ = return Authorized
    isAuthorized Hello785R _ = return Authorized
    isAuthorized Hello786R _ = return Authorized
    isAuthorized Hello787R _ = return Authorized
    isAuthorized Hello788R _ = return Authorized
    isAuthorized Hello789R _ = return Authorized
    isAuthorized Hello790R _ = return Authorized
    isAuthorized Hello791R _ = return Authorized
    isAuthorized Hello792R _ = return Authorized
    isAuthorized Hello793R _ = return Authorized
    isAuthorized Hello794R _ = return Authorized
    isAuthorized Hello795R _ = return Authorized
    isAuthorized Hello796R _ = return Authorized
    isAuthorized Hello797R _ = return Authorized
    isAuthorized Hello798R _ = return Authorized
    isAuthorized Hello799R _ = return Authorized
    isAuthorized Hello800R _ = return Authorized
    isAuthorized Hello801R _ = return Authorized
    isAuthorized Hello802R _ = return Authorized
    isAuthorized Hello803R _ = return Authorized
    isAuthorized Hello804R _ = return Authorized
    isAuthorized Hello805R _ = return Authorized
    isAuthorized Hello806R _ = return Authorized
    isAuthorized Hello807R _ = return Authorized
    isAuthorized Hello808R _ = return Authorized
    isAuthorized Hello809R _ = return Authorized
    isAuthorized Hello810R _ = return Authorized
    isAuthorized Hello811R _ = return Authorized
    isAuthorized Hello812R _ = return Authorized
    isAuthorized Hello813R _ = return Authorized
    isAuthorized Hello814R _ = return Authorized
    isAuthorized Hello815R _ = return Authorized
    isAuthorized Hello816R _ = return Authorized
    isAuthorized Hello817R _ = return Authorized
    isAuthorized Hello818R _ = return Authorized
    isAuthorized Hello819R _ = return Authorized
    isAuthorized Hello820R _ = return Authorized
    isAuthorized Hello821R _ = return Authorized
    isAuthorized Hello822R _ = return Authorized
    isAuthorized Hello823R _ = return Authorized
    isAuthorized Hello824R _ = return Authorized
    isAuthorized Hello825R _ = return Authorized
    isAuthorized Hello826R _ = return Authorized
    isAuthorized Hello827R _ = return Authorized
    isAuthorized Hello828R _ = return Authorized
    isAuthorized Hello829R _ = return Authorized
    isAuthorized Hello830R _ = return Authorized
    isAuthorized Hello831R _ = return Authorized
    isAuthorized Hello832R _ = return Authorized
    isAuthorized Hello833R _ = return Authorized
    isAuthorized Hello834R _ = return Authorized
    isAuthorized Hello835R _ = return Authorized
    isAuthorized Hello836R _ = return Authorized
    isAuthorized Hello837R _ = return Authorized
    isAuthorized Hello838R _ = return Authorized
    isAuthorized Hello839R _ = return Authorized
    isAuthorized Hello840R _ = return Authorized
    isAuthorized Hello841R _ = return Authorized
    isAuthorized Hello842R _ = return Authorized
    isAuthorized Hello843R _ = return Authorized
    isAuthorized Hello844R _ = return Authorized
    isAuthorized Hello845R _ = return Authorized
    isAuthorized Hello846R _ = return Authorized
    isAuthorized Hello847R _ = return Authorized
    isAuthorized Hello848R _ = return Authorized
    isAuthorized Hello849R _ = return Authorized
    isAuthorized Hello850R _ = return Authorized
    isAuthorized Hello851R _ = return Authorized
    isAuthorized Hello852R _ = return Authorized
    isAuthorized Hello853R _ = return Authorized
    isAuthorized Hello854R _ = return Authorized
    isAuthorized Hello855R _ = return Authorized
    isAuthorized Hello856R _ = return Authorized
    isAuthorized Hello857R _ = return Authorized
    isAuthorized Hello858R _ = return Authorized
    isAuthorized Hello859R _ = return Authorized
    isAuthorized Hello860R _ = return Authorized
    isAuthorized Hello861R _ = return Authorized
    isAuthorized Hello862R _ = return Authorized
    isAuthorized Hello863R _ = return Authorized
    isAuthorized Hello864R _ = return Authorized
    isAuthorized Hello865R _ = return Authorized
    isAuthorized Hello866R _ = return Authorized
    isAuthorized Hello867R _ = return Authorized
    isAuthorized Hello868R _ = return Authorized
    isAuthorized Hello869R _ = return Authorized
    isAuthorized Hello870R _ = return Authorized
    isAuthorized Hello871R _ = return Authorized
    isAuthorized Hello872R _ = return Authorized
    isAuthorized Hello873R _ = return Authorized
    isAuthorized Hello874R _ = return Authorized
    isAuthorized Hello875R _ = return Authorized
    isAuthorized Hello876R _ = return Authorized
    isAuthorized Hello877R _ = return Authorized
    isAuthorized Hello878R _ = return Authorized
    isAuthorized Hello879R _ = return Authorized
    isAuthorized Hello880R _ = return Authorized
    isAuthorized Hello881R _ = return Authorized
    isAuthorized Hello882R _ = return Authorized
    isAuthorized Hello883R _ = return Authorized
    isAuthorized Hello884R _ = return Authorized
    isAuthorized Hello885R _ = return Authorized
    isAuthorized Hello886R _ = return Authorized
    isAuthorized Hello887R _ = return Authorized
    isAuthorized Hello888R _ = return Authorized
    isAuthorized Hello889R _ = return Authorized
    isAuthorized Hello890R _ = return Authorized
    isAuthorized Hello891R _ = return Authorized
    isAuthorized Hello892R _ = return Authorized
    isAuthorized Hello893R _ = return Authorized
    isAuthorized Hello894R _ = return Authorized
    isAuthorized Hello895R _ = return Authorized
    isAuthorized Hello896R _ = return Authorized
    isAuthorized Hello897R _ = return Authorized
    isAuthorized Hello898R _ = return Authorized
    isAuthorized Hello899R _ = return Authorized
    isAuthorized Hello900R _ = return Authorized
    isAuthorized Hello901R _ = return Authorized
    isAuthorized Hello902R _ = return Authorized
    isAuthorized Hello903R _ = return Authorized
    isAuthorized Hello904R _ = return Authorized
    isAuthorized Hello905R _ = return Authorized
    isAuthorized Hello906R _ = return Authorized
    isAuthorized Hello907R _ = return Authorized
    isAuthorized Hello908R _ = return Authorized
    isAuthorized Hello909R _ = return Authorized
    isAuthorized Hello910R _ = return Authorized
    isAuthorized Hello911R _ = return Authorized
    isAuthorized Hello912R _ = return Authorized
    isAuthorized Hello913R _ = return Authorized
    isAuthorized Hello914R _ = return Authorized
    isAuthorized Hello915R _ = return Authorized
    isAuthorized Hello916R _ = return Authorized
    isAuthorized Hello917R _ = return Authorized
    isAuthorized Hello918R _ = return Authorized
    isAuthorized Hello919R _ = return Authorized
    isAuthorized Hello920R _ = return Authorized
    isAuthorized Hello921R _ = return Authorized
    isAuthorized Hello922R _ = return Authorized
    isAuthorized Hello923R _ = return Authorized
    isAuthorized Hello924R _ = return Authorized
    isAuthorized Hello925R _ = return Authorized
    isAuthorized Hello926R _ = return Authorized
    isAuthorized Hello927R _ = return Authorized
    isAuthorized Hello928R _ = return Authorized
    isAuthorized Hello929R _ = return Authorized
    isAuthorized Hello930R _ = return Authorized
    isAuthorized Hello931R _ = return Authorized
    isAuthorized Hello932R _ = return Authorized
    isAuthorized Hello933R _ = return Authorized
    isAuthorized Hello934R _ = return Authorized
    isAuthorized Hello935R _ = return Authorized
    isAuthorized Hello936R _ = return Authorized
    isAuthorized Hello937R _ = return Authorized
    isAuthorized Hello938R _ = return Authorized
    isAuthorized Hello939R _ = return Authorized
    isAuthorized Hello940R _ = return Authorized
    isAuthorized Hello941R _ = return Authorized
    isAuthorized Hello942R _ = return Authorized
    isAuthorized Hello943R _ = return Authorized
    isAuthorized Hello944R _ = return Authorized
    isAuthorized Hello945R _ = return Authorized
    isAuthorized Hello946R _ = return Authorized
    isAuthorized Hello947R _ = return Authorized
    isAuthorized Hello948R _ = return Authorized
    isAuthorized Hello949R _ = return Authorized
    isAuthorized Hello950R _ = return Authorized
    isAuthorized Hello951R _ = return Authorized
    isAuthorized Hello952R _ = return Authorized
    isAuthorized Hello953R _ = return Authorized
    isAuthorized Hello954R _ = return Authorized
    isAuthorized Hello955R _ = return Authorized
    isAuthorized Hello956R _ = return Authorized
    isAuthorized Hello957R _ = return Authorized
    isAuthorized Hello958R _ = return Authorized
    isAuthorized Hello959R _ = return Authorized
    isAuthorized Hello960R _ = return Authorized
    isAuthorized Hello961R _ = return Authorized
    isAuthorized Hello962R _ = return Authorized
    isAuthorized Hello963R _ = return Authorized
    isAuthorized Hello964R _ = return Authorized
    isAuthorized Hello965R _ = return Authorized
    isAuthorized Hello966R _ = return Authorized
    isAuthorized Hello967R _ = return Authorized
    isAuthorized Hello968R _ = return Authorized
    isAuthorized Hello969R _ = return Authorized
    isAuthorized Hello970R _ = return Authorized
    isAuthorized Hello971R _ = return Authorized
    isAuthorized Hello972R _ = return Authorized
    isAuthorized Hello973R _ = return Authorized
    isAuthorized Hello974R _ = return Authorized
    isAuthorized Hello975R _ = return Authorized
    isAuthorized Hello976R _ = return Authorized
    isAuthorized Hello977R _ = return Authorized
    isAuthorized Hello978R _ = return Authorized
    isAuthorized Hello979R _ = return Authorized
    isAuthorized Hello980R _ = return Authorized
    isAuthorized Hello981R _ = return Authorized
    isAuthorized Hello982R _ = return Authorized
    isAuthorized Hello983R _ = return Authorized
    isAuthorized Hello984R _ = return Authorized
    isAuthorized Hello985R _ = return Authorized
    isAuthorized Hello986R _ = return Authorized
    isAuthorized Hello987R _ = return Authorized
    isAuthorized Hello988R _ = return Authorized
    isAuthorized Hello989R _ = return Authorized
    isAuthorized Hello990R _ = return Authorized
    isAuthorized Hello991R _ = return Authorized
    isAuthorized Hello992R _ = return Authorized
    isAuthorized Hello993R _ = return Authorized
    isAuthorized Hello994R _ = return Authorized
    isAuthorized Hello995R _ = return Authorized
    isAuthorized Hello996R _ = return Authorized
    isAuthorized Hello997R _ = return Authorized
    isAuthorized Hello998R _ = return Authorized
    isAuthorized Hello999R _ = return Authorized
    isAuthorized Hello1000R _ = return Authorized
    isAuthorized Hello1001R _ = return Authorized
    isAuthorized Hello1002R _ = return Authorized
    isAuthorized Hello1003R _ = return Authorized
    isAuthorized Hello1004R _ = return Authorized
    isAuthorized Hello1005R _ = return Authorized
    isAuthorized Hello1006R _ = return Authorized
    isAuthorized Hello1007R _ = return Authorized
    isAuthorized Hello1008R _ = return Authorized
    isAuthorized Hello1009R _ = return Authorized
    isAuthorized Hello1010R _ = return Authorized
    isAuthorized Hello1011R _ = return Authorized
    isAuthorized Hello1012R _ = return Authorized
    isAuthorized Hello1013R _ = return Authorized
    isAuthorized Hello1014R _ = return Authorized
    isAuthorized Hello1015R _ = return Authorized
    isAuthorized Hello1016R _ = return Authorized
    isAuthorized Hello1017R _ = return Authorized
    isAuthorized Hello1018R _ = return Authorized
    isAuthorized Hello1019R _ = return Authorized
    isAuthorized Hello1020R _ = return Authorized
    isAuthorized Hello1021R _ = return Authorized
    isAuthorized Hello1022R _ = return Authorized
    isAuthorized Hello1023R _ = return Authorized
    isAuthorized Hello1024R _ = return Authorized
    isAuthorized Hello1025R _ = return Authorized
    isAuthorized Hello1026R _ = return Authorized
    isAuthorized Hello1027R _ = return Authorized
    isAuthorized Hello1028R _ = return Authorized
    isAuthorized Hello1029R _ = return Authorized
    isAuthorized Hello1030R _ = return Authorized
    isAuthorized Hello1031R _ = return Authorized
    isAuthorized Hello1032R _ = return Authorized
    isAuthorized Hello1033R _ = return Authorized
    isAuthorized Hello1034R _ = return Authorized
    isAuthorized Hello1035R _ = return Authorized
    isAuthorized Hello1036R _ = return Authorized
    isAuthorized Hello1037R _ = return Authorized
    isAuthorized Hello1038R _ = return Authorized
    isAuthorized Hello1039R _ = return Authorized
    isAuthorized Hello1040R _ = return Authorized
    isAuthorized Hello1041R _ = return Authorized
    isAuthorized Hello1042R _ = return Authorized
    isAuthorized Hello1043R _ = return Authorized
    isAuthorized Hello1044R _ = return Authorized
    isAuthorized Hello1045R _ = return Authorized
    isAuthorized Hello1046R _ = return Authorized
    isAuthorized Hello1047R _ = return Authorized
    isAuthorized Hello1048R _ = return Authorized
    isAuthorized Hello1049R _ = return Authorized
    isAuthorized Hello1050R _ = return Authorized
    isAuthorized Hello1051R _ = return Authorized
    isAuthorized Hello1052R _ = return Authorized
    isAuthorized Hello1053R _ = return Authorized
    isAuthorized Hello1054R _ = return Authorized
    isAuthorized Hello1055R _ = return Authorized
    isAuthorized Hello1056R _ = return Authorized
    isAuthorized Hello1057R _ = return Authorized
    isAuthorized Hello1058R _ = return Authorized
    isAuthorized Hello1059R _ = return Authorized
    isAuthorized Hello1060R _ = return Authorized
    isAuthorized Hello1061R _ = return Authorized
    isAuthorized Hello1062R _ = return Authorized
    isAuthorized Hello1063R _ = return Authorized
    isAuthorized Hello1064R _ = return Authorized
    isAuthorized Hello1065R _ = return Authorized
    isAuthorized Hello1066R _ = return Authorized
    isAuthorized Hello1067R _ = return Authorized
    isAuthorized Hello1068R _ = return Authorized
    isAuthorized Hello1069R _ = return Authorized
    isAuthorized Hello1070R _ = return Authorized
    isAuthorized Hello1071R _ = return Authorized
    isAuthorized Hello1072R _ = return Authorized
    isAuthorized Hello1073R _ = return Authorized
    isAuthorized Hello1074R _ = return Authorized
    isAuthorized Hello1075R _ = return Authorized
    isAuthorized Hello1076R _ = return Authorized
    isAuthorized Hello1077R _ = return Authorized
    isAuthorized Hello1078R _ = return Authorized
    isAuthorized Hello1079R _ = return Authorized
    isAuthorized Hello1080R _ = return Authorized
    isAuthorized Hello1081R _ = return Authorized
    isAuthorized Hello1082R _ = return Authorized
    isAuthorized Hello1083R _ = return Authorized
    isAuthorized Hello1084R _ = return Authorized
    isAuthorized Hello1085R _ = return Authorized
    isAuthorized Hello1086R _ = return Authorized
    isAuthorized Hello1087R _ = return Authorized
    isAuthorized Hello1088R _ = return Authorized
    isAuthorized Hello1089R _ = return Authorized
    isAuthorized Hello1090R _ = return Authorized
    isAuthorized Hello1091R _ = return Authorized
    isAuthorized Hello1092R _ = return Authorized
    isAuthorized Hello1093R _ = return Authorized
    isAuthorized Hello1094R _ = return Authorized
    isAuthorized Hello1095R _ = return Authorized
    isAuthorized Hello1096R _ = return Authorized
    isAuthorized Hello1097R _ = return Authorized
    isAuthorized Hello1098R _ = return Authorized
    isAuthorized Hello1099R _ = return Authorized
    isAuthorized Hello1100R _ = return Authorized
    isAuthorized Hello1101R _ = return Authorized
    isAuthorized Hello1102R _ = return Authorized
    isAuthorized Hello1103R _ = return Authorized
    isAuthorized Hello1104R _ = return Authorized
    isAuthorized Hello1105R _ = return Authorized
    isAuthorized Hello1106R _ = return Authorized
    isAuthorized Hello1107R _ = return Authorized
    isAuthorized Hello1108R _ = return Authorized
    isAuthorized Hello1109R _ = return Authorized
    isAuthorized Hello1110R _ = return Authorized
    isAuthorized Hello1111R _ = return Authorized
    isAuthorized Hello1112R _ = return Authorized
    isAuthorized Hello1113R _ = return Authorized
    isAuthorized Hello1114R _ = return Authorized
    isAuthorized Hello1115R _ = return Authorized
    isAuthorized Hello1116R _ = return Authorized
    isAuthorized Hello1117R _ = return Authorized
    isAuthorized Hello1118R _ = return Authorized
    isAuthorized Hello1119R _ = return Authorized
    isAuthorized Hello1120R _ = return Authorized
    isAuthorized Hello1121R _ = return Authorized
    isAuthorized Hello1122R _ = return Authorized
    isAuthorized Hello1123R _ = return Authorized
    isAuthorized Hello1124R _ = return Authorized
    isAuthorized Hello1125R _ = return Authorized
    isAuthorized Hello1126R _ = return Authorized
    isAuthorized Hello1127R _ = return Authorized
    isAuthorized Hello1128R _ = return Authorized
    isAuthorized Hello1129R _ = return Authorized
    isAuthorized Hello1130R _ = return Authorized
    isAuthorized Hello1131R _ = return Authorized
    isAuthorized Hello1132R _ = return Authorized
    isAuthorized Hello1133R _ = return Authorized
    isAuthorized Hello1134R _ = return Authorized
    isAuthorized Hello1135R _ = return Authorized
    isAuthorized Hello1136R _ = return Authorized
    isAuthorized Hello1137R _ = return Authorized
    isAuthorized Hello1138R _ = return Authorized
    isAuthorized Hello1139R _ = return Authorized
    isAuthorized Hello1140R _ = return Authorized
    isAuthorized Hello1141R _ = return Authorized
    isAuthorized Hello1142R _ = return Authorized
    isAuthorized Hello1143R _ = return Authorized
    isAuthorized Hello1144R _ = return Authorized
    isAuthorized Hello1145R _ = return Authorized
    isAuthorized Hello1146R _ = return Authorized
    isAuthorized Hello1147R _ = return Authorized
    isAuthorized Hello1148R _ = return Authorized
    isAuthorized Hello1149R _ = return Authorized
    isAuthorized Hello1150R _ = return Authorized
    isAuthorized Hello1151R _ = return Authorized
    isAuthorized Hello1152R _ = return Authorized
    isAuthorized Hello1153R _ = return Authorized
    isAuthorized Hello1154R _ = return Authorized
    isAuthorized Hello1155R _ = return Authorized
    isAuthorized Hello1156R _ = return Authorized
    isAuthorized Hello1157R _ = return Authorized
    isAuthorized Hello1158R _ = return Authorized
    isAuthorized Hello1159R _ = return Authorized
    isAuthorized Hello1160R _ = return Authorized
    isAuthorized Hello1161R _ = return Authorized
    isAuthorized Hello1162R _ = return Authorized
    isAuthorized Hello1163R _ = return Authorized
    isAuthorized Hello1164R _ = return Authorized
    isAuthorized Hello1165R _ = return Authorized
    isAuthorized Hello1166R _ = return Authorized
    isAuthorized Hello1167R _ = return Authorized
    isAuthorized Hello1168R _ = return Authorized
    isAuthorized Hello1169R _ = return Authorized
    isAuthorized Hello1170R _ = return Authorized
    isAuthorized Hello1171R _ = return Authorized
    isAuthorized Hello1172R _ = return Authorized
    isAuthorized Hello1173R _ = return Authorized
    isAuthorized Hello1174R _ = return Authorized
    isAuthorized Hello1175R _ = return Authorized
    isAuthorized Hello1176R _ = return Authorized
    isAuthorized Hello1177R _ = return Authorized
    isAuthorized Hello1178R _ = return Authorized
    isAuthorized Hello1179R _ = return Authorized
    isAuthorized Hello1180R _ = return Authorized
    isAuthorized Hello1181R _ = return Authorized
    isAuthorized Hello1182R _ = return Authorized
    isAuthorized Hello1183R _ = return Authorized
    isAuthorized Hello1184R _ = return Authorized
    isAuthorized Hello1185R _ = return Authorized
    isAuthorized Hello1186R _ = return Authorized
    isAuthorized Hello1187R _ = return Authorized
    isAuthorized Hello1188R _ = return Authorized
    isAuthorized Hello1189R _ = return Authorized
    isAuthorized Hello1190R _ = return Authorized
    isAuthorized Hello1191R _ = return Authorized
    isAuthorized Hello1192R _ = return Authorized
    isAuthorized Hello1193R _ = return Authorized
    isAuthorized Hello1194R _ = return Authorized
    isAuthorized Hello1195R _ = return Authorized
    isAuthorized Hello1196R _ = return Authorized
    isAuthorized Hello1197R _ = return Authorized
    isAuthorized Hello1198R _ = return Authorized
    isAuthorized Hello1199R _ = return Authorized
    isAuthorized Hello1200R _ = return Authorized
    isAuthorized Hello1201R _ = return Authorized
    isAuthorized Hello1202R _ = return Authorized
    isAuthorized Hello1203R _ = return Authorized
    isAuthorized Hello1204R _ = return Authorized
    isAuthorized Hello1205R _ = return Authorized
    isAuthorized Hello1206R _ = return Authorized
    isAuthorized Hello1207R _ = return Authorized
    isAuthorized Hello1208R _ = return Authorized
    isAuthorized Hello1209R _ = return Authorized
    isAuthorized Hello1210R _ = return Authorized
    isAuthorized Hello1211R _ = return Authorized
    isAuthorized Hello1212R _ = return Authorized
    isAuthorized Hello1213R _ = return Authorized
    isAuthorized Hello1214R _ = return Authorized
    isAuthorized Hello1215R _ = return Authorized
    isAuthorized Hello1216R _ = return Authorized
    isAuthorized Hello1217R _ = return Authorized
    isAuthorized Hello1218R _ = return Authorized
    isAuthorized Hello1219R _ = return Authorized
    isAuthorized Hello1220R _ = return Authorized
    isAuthorized Hello1221R _ = return Authorized
    isAuthorized Hello1222R _ = return Authorized
    isAuthorized Hello1223R _ = return Authorized
    isAuthorized Hello1224R _ = return Authorized
    isAuthorized Hello1225R _ = return Authorized
    isAuthorized Hello1226R _ = return Authorized
    isAuthorized Hello1227R _ = return Authorized
    isAuthorized Hello1228R _ = return Authorized
    isAuthorized Hello1229R _ = return Authorized
    isAuthorized Hello1230R _ = return Authorized
    isAuthorized Hello1231R _ = return Authorized
    isAuthorized Hello1232R _ = return Authorized
    isAuthorized Hello1233R _ = return Authorized
    isAuthorized Hello1234R _ = return Authorized
    isAuthorized Hello1235R _ = return Authorized
    isAuthorized Hello1236R _ = return Authorized
    isAuthorized Hello1237R _ = return Authorized
    isAuthorized Hello1238R _ = return Authorized
    isAuthorized Hello1239R _ = return Authorized
    isAuthorized Hello1240R _ = return Authorized
    isAuthorized Hello1241R _ = return Authorized
    isAuthorized Hello1242R _ = return Authorized
    isAuthorized Hello1243R _ = return Authorized
    isAuthorized Hello1244R _ = return Authorized
    isAuthorized Hello1245R _ = return Authorized
    isAuthorized Hello1246R _ = return Authorized
    isAuthorized Hello1247R _ = return Authorized
    isAuthorized Hello1248R _ = return Authorized
    isAuthorized Hello1249R _ = return Authorized
    isAuthorized Hello1250R _ = return Authorized
    isAuthorized Hello1251R _ = return Authorized
    isAuthorized Hello1252R _ = return Authorized
    isAuthorized Hello1253R _ = return Authorized
    isAuthorized Hello1254R _ = return Authorized
    isAuthorized Hello1255R _ = return Authorized
    isAuthorized Hello1256R _ = return Authorized
    isAuthorized Hello1257R _ = return Authorized
    isAuthorized Hello1258R _ = return Authorized
    isAuthorized Hello1259R _ = return Authorized
    isAuthorized Hello1260R _ = return Authorized
    isAuthorized Hello1261R _ = return Authorized
    isAuthorized Hello1262R _ = return Authorized
    isAuthorized Hello1263R _ = return Authorized
    isAuthorized Hello1264R _ = return Authorized
    isAuthorized Hello1265R _ = return Authorized
    isAuthorized Hello1266R _ = return Authorized
    isAuthorized Hello1267R _ = return Authorized
    isAuthorized Hello1268R _ = return Authorized
    isAuthorized Hello1269R _ = return Authorized
    isAuthorized Hello1270R _ = return Authorized
    isAuthorized Hello1271R _ = return Authorized
    isAuthorized Hello1272R _ = return Authorized
    isAuthorized Hello1273R _ = return Authorized
    isAuthorized Hello1274R _ = return Authorized
    isAuthorized Hello1275R _ = return Authorized
    isAuthorized Hello1276R _ = return Authorized
    isAuthorized Hello1277R _ = return Authorized
    isAuthorized Hello1278R _ = return Authorized
    isAuthorized Hello1279R _ = return Authorized
    isAuthorized Hello1280R _ = return Authorized
    isAuthorized Hello1281R _ = return Authorized
    isAuthorized Hello1282R _ = return Authorized
    isAuthorized Hello1283R _ = return Authorized
    isAuthorized Hello1284R _ = return Authorized
    isAuthorized Hello1285R _ = return Authorized
    isAuthorized Hello1286R _ = return Authorized
    isAuthorized Hello1287R _ = return Authorized
    isAuthorized Hello1288R _ = return Authorized
    isAuthorized Hello1289R _ = return Authorized
    isAuthorized Hello1290R _ = return Authorized
    isAuthorized Hello1291R _ = return Authorized
    isAuthorized Hello1292R _ = return Authorized
    isAuthorized Hello1293R _ = return Authorized
    isAuthorized Hello1294R _ = return Authorized
    isAuthorized Hello1295R _ = return Authorized
    isAuthorized Hello1296R _ = return Authorized
    isAuthorized Hello1297R _ = return Authorized
    isAuthorized Hello1298R _ = return Authorized
    isAuthorized Hello1299R _ = return Authorized
    isAuthorized Hello1300R _ = return Authorized
    isAuthorized Hello1301R _ = return Authorized
    isAuthorized Hello1302R _ = return Authorized
    isAuthorized Hello1303R _ = return Authorized
    isAuthorized Hello1304R _ = return Authorized
    isAuthorized Hello1305R _ = return Authorized
    isAuthorized Hello1306R _ = return Authorized
    isAuthorized Hello1307R _ = return Authorized
    isAuthorized Hello1308R _ = return Authorized
    isAuthorized Hello1309R _ = return Authorized
    isAuthorized Hello1310R _ = return Authorized
    isAuthorized Hello1311R _ = return Authorized
    isAuthorized Hello1312R _ = return Authorized
    isAuthorized Hello1313R _ = return Authorized
    isAuthorized Hello1314R _ = return Authorized
    isAuthorized Hello1315R _ = return Authorized
    isAuthorized Hello1316R _ = return Authorized
    isAuthorized Hello1317R _ = return Authorized
    isAuthorized Hello1318R _ = return Authorized
    isAuthorized Hello1319R _ = return Authorized
    isAuthorized Hello1320R _ = return Authorized
    isAuthorized Hello1321R _ = return Authorized
    isAuthorized Hello1322R _ = return Authorized
    isAuthorized Hello1323R _ = return Authorized
    isAuthorized Hello1324R _ = return Authorized
    isAuthorized Hello1325R _ = return Authorized
    isAuthorized Hello1326R _ = return Authorized
    isAuthorized Hello1327R _ = return Authorized
    isAuthorized Hello1328R _ = return Authorized
    isAuthorized Hello1329R _ = return Authorized
    isAuthorized Hello1330R _ = return Authorized
    isAuthorized Hello1331R _ = return Authorized
    isAuthorized Hello1332R _ = return Authorized
    isAuthorized Hello1333R _ = return Authorized
    isAuthorized Hello1334R _ = return Authorized
    isAuthorized Hello1335R _ = return Authorized
    isAuthorized Hello1336R _ = return Authorized
    isAuthorized Hello1337R _ = return Authorized
    isAuthorized Hello1338R _ = return Authorized
    isAuthorized Hello1339R _ = return Authorized
    isAuthorized Hello1340R _ = return Authorized
    isAuthorized Hello1341R _ = return Authorized
    isAuthorized Hello1342R _ = return Authorized
    isAuthorized Hello1343R _ = return Authorized
    isAuthorized Hello1344R _ = return Authorized
    isAuthorized Hello1345R _ = return Authorized
    isAuthorized Hello1346R _ = return Authorized
    isAuthorized Hello1347R _ = return Authorized
    isAuthorized Hello1348R _ = return Authorized
    isAuthorized Hello1349R _ = return Authorized
    isAuthorized Hello1350R _ = return Authorized
    isAuthorized Hello1351R _ = return Authorized
    isAuthorized Hello1352R _ = return Authorized
    isAuthorized Hello1353R _ = return Authorized
    isAuthorized Hello1354R _ = return Authorized
    isAuthorized Hello1355R _ = return Authorized
    isAuthorized Hello1356R _ = return Authorized
    isAuthorized Hello1357R _ = return Authorized
    isAuthorized Hello1358R _ = return Authorized
    isAuthorized Hello1359R _ = return Authorized
    isAuthorized Hello1360R _ = return Authorized
    isAuthorized Hello1361R _ = return Authorized
    isAuthorized Hello1362R _ = return Authorized
    isAuthorized Hello1363R _ = return Authorized
    isAuthorized Hello1364R _ = return Authorized
    isAuthorized Hello1365R _ = return Authorized
    isAuthorized Hello1366R _ = return Authorized
    isAuthorized Hello1367R _ = return Authorized
    isAuthorized Hello1368R _ = return Authorized
    isAuthorized Hello1369R _ = return Authorized
    isAuthorized Hello1370R _ = return Authorized
    isAuthorized Hello1371R _ = return Authorized
    isAuthorized Hello1372R _ = return Authorized
    isAuthorized Hello1373R _ = return Authorized
    isAuthorized Hello1374R _ = return Authorized
    isAuthorized Hello1375R _ = return Authorized
    isAuthorized Hello1376R _ = return Authorized
    isAuthorized Hello1377R _ = return Authorized
    isAuthorized Hello1378R _ = return Authorized
    isAuthorized Hello1379R _ = return Authorized
    isAuthorized Hello1380R _ = return Authorized
    isAuthorized Hello1381R _ = return Authorized
    isAuthorized Hello1382R _ = return Authorized
    isAuthorized Hello1383R _ = return Authorized
    isAuthorized Hello1384R _ = return Authorized
    isAuthorized Hello1385R _ = return Authorized
    isAuthorized Hello1386R _ = return Authorized
    isAuthorized Hello1387R _ = return Authorized
    isAuthorized Hello1388R _ = return Authorized
    isAuthorized Hello1389R _ = return Authorized
    isAuthorized Hello1390R _ = return Authorized
    isAuthorized Hello1391R _ = return Authorized
    isAuthorized Hello1392R _ = return Authorized
    isAuthorized Hello1393R _ = return Authorized
    isAuthorized Hello1394R _ = return Authorized
    isAuthorized Hello1395R _ = return Authorized
    isAuthorized Hello1396R _ = return Authorized
    isAuthorized Hello1397R _ = return Authorized
    isAuthorized Hello1398R _ = return Authorized
    isAuthorized Hello1399R _ = return Authorized
    isAuthorized Hello1400R _ = return Authorized
    isAuthorized Hello1401R _ = return Authorized
    isAuthorized Hello1402R _ = return Authorized
    isAuthorized Hello1403R _ = return Authorized
    isAuthorized Hello1404R _ = return Authorized
    isAuthorized Hello1405R _ = return Authorized
    isAuthorized Hello1406R _ = return Authorized
    isAuthorized Hello1407R _ = return Authorized
    isAuthorized Hello1408R _ = return Authorized
    isAuthorized Hello1409R _ = return Authorized
    isAuthorized Hello1410R _ = return Authorized
    isAuthorized Hello1411R _ = return Authorized
    isAuthorized Hello1412R _ = return Authorized
    isAuthorized Hello1413R _ = return Authorized
    isAuthorized Hello1414R _ = return Authorized
    isAuthorized Hello1415R _ = return Authorized
    isAuthorized Hello1416R _ = return Authorized
    isAuthorized Hello1417R _ = return Authorized
    isAuthorized Hello1418R _ = return Authorized
    isAuthorized Hello1419R _ = return Authorized
    isAuthorized Hello1420R _ = return Authorized
    isAuthorized Hello1421R _ = return Authorized
    isAuthorized Hello1422R _ = return Authorized
    isAuthorized Hello1423R _ = return Authorized
    isAuthorized Hello1424R _ = return Authorized
    isAuthorized Hello1425R _ = return Authorized
    isAuthorized Hello1426R _ = return Authorized
    isAuthorized Hello1427R _ = return Authorized
    isAuthorized Hello1428R _ = return Authorized
    isAuthorized Hello1429R _ = return Authorized
    isAuthorized Hello1430R _ = return Authorized
    isAuthorized Hello1431R _ = return Authorized
    isAuthorized Hello1432R _ = return Authorized
    isAuthorized Hello1433R _ = return Authorized
    isAuthorized Hello1434R _ = return Authorized
    isAuthorized Hello1435R _ = return Authorized
    isAuthorized Hello1436R _ = return Authorized
    isAuthorized Hello1437R _ = return Authorized
    isAuthorized Hello1438R _ = return Authorized
    isAuthorized Hello1439R _ = return Authorized
    isAuthorized Hello1440R _ = return Authorized
    isAuthorized Hello1441R _ = return Authorized
    isAuthorized Hello1442R _ = return Authorized
    isAuthorized Hello1443R _ = return Authorized
    isAuthorized Hello1444R _ = return Authorized
    isAuthorized Hello1445R _ = return Authorized
    isAuthorized Hello1446R _ = return Authorized
    isAuthorized Hello1447R _ = return Authorized
    isAuthorized Hello1448R _ = return Authorized
    isAuthorized Hello1449R _ = return Authorized
    isAuthorized Hello1450R _ = return Authorized
    isAuthorized Hello1451R _ = return Authorized
    isAuthorized Hello1452R _ = return Authorized
    isAuthorized Hello1453R _ = return Authorized
    isAuthorized Hello1454R _ = return Authorized
    isAuthorized Hello1455R _ = return Authorized
    isAuthorized Hello1456R _ = return Authorized
    isAuthorized Hello1457R _ = return Authorized
    isAuthorized Hello1458R _ = return Authorized
    isAuthorized Hello1459R _ = return Authorized
    isAuthorized Hello1460R _ = return Authorized
    isAuthorized Hello1461R _ = return Authorized
    isAuthorized Hello1462R _ = return Authorized
    isAuthorized Hello1463R _ = return Authorized
    isAuthorized Hello1464R _ = return Authorized
    isAuthorized Hello1465R _ = return Authorized
    isAuthorized Hello1466R _ = return Authorized
    isAuthorized Hello1467R _ = return Authorized
    isAuthorized Hello1468R _ = return Authorized
    isAuthorized Hello1469R _ = return Authorized
    isAuthorized Hello1470R _ = return Authorized
    isAuthorized Hello1471R _ = return Authorized
    isAuthorized Hello1472R _ = return Authorized
    isAuthorized Hello1473R _ = return Authorized
    isAuthorized Hello1474R _ = return Authorized
    isAuthorized Hello1475R _ = return Authorized
    isAuthorized Hello1476R _ = return Authorized
    isAuthorized Hello1477R _ = return Authorized
    isAuthorized Hello1478R _ = return Authorized
    isAuthorized Hello1479R _ = return Authorized
    isAuthorized Hello1480R _ = return Authorized
    isAuthorized Hello1481R _ = return Authorized
    isAuthorized Hello1482R _ = return Authorized
    isAuthorized Hello1483R _ = return Authorized
    isAuthorized Hello1484R _ = return Authorized
    isAuthorized Hello1485R _ = return Authorized
    isAuthorized Hello1486R _ = return Authorized
    isAuthorized Hello1487R _ = return Authorized
    isAuthorized Hello1488R _ = return Authorized
    isAuthorized Hello1489R _ = return Authorized
    isAuthorized Hello1490R _ = return Authorized
    isAuthorized Hello1491R _ = return Authorized
    isAuthorized Hello1492R _ = return Authorized
    isAuthorized Hello1493R _ = return Authorized
    isAuthorized Hello1494R _ = return Authorized
    isAuthorized Hello1495R _ = return Authorized
    isAuthorized Hello1496R _ = return Authorized
    isAuthorized Hello1497R _ = return Authorized
    isAuthorized Hello1498R _ = return Authorized
    isAuthorized Hello1499R _ = return Authorized
    isAuthorized Hello1500R _ = return Authorized
    isAuthorized Hello1501R _ = return Authorized
    isAuthorized Hello1502R _ = return Authorized
    isAuthorized Hello1503R _ = return Authorized
    isAuthorized Hello1504R _ = return Authorized
    isAuthorized Hello1505R _ = return Authorized
    isAuthorized Hello1506R _ = return Authorized
    isAuthorized Hello1507R _ = return Authorized
    isAuthorized Hello1508R _ = return Authorized
    isAuthorized Hello1509R _ = return Authorized
    isAuthorized Hello1510R _ = return Authorized
    isAuthorized Hello1511R _ = return Authorized
    isAuthorized Hello1512R _ = return Authorized
    isAuthorized Hello1513R _ = return Authorized
    isAuthorized Hello1514R _ = return Authorized
    isAuthorized Hello1515R _ = return Authorized
    isAuthorized Hello1516R _ = return Authorized
    isAuthorized Hello1517R _ = return Authorized
    isAuthorized Hello1518R _ = return Authorized
    isAuthorized Hello1519R _ = return Authorized
    isAuthorized Hello1520R _ = return Authorized
    isAuthorized Hello1521R _ = return Authorized
    isAuthorized Hello1522R _ = return Authorized
    isAuthorized Hello1523R _ = return Authorized
    isAuthorized Hello1524R _ = return Authorized
    isAuthorized Hello1525R _ = return Authorized
    isAuthorized Hello1526R _ = return Authorized
    isAuthorized Hello1527R _ = return Authorized
    isAuthorized Hello1528R _ = return Authorized
    isAuthorized Hello1529R _ = return Authorized
    isAuthorized Hello1530R _ = return Authorized
    isAuthorized Hello1531R _ = return Authorized
    isAuthorized Hello1532R _ = return Authorized
    isAuthorized Hello1533R _ = return Authorized
    isAuthorized Hello1534R _ = return Authorized
    isAuthorized Hello1535R _ = return Authorized
    isAuthorized Hello1536R _ = return Authorized
    isAuthorized Hello1537R _ = return Authorized
    isAuthorized Hello1538R _ = return Authorized
    isAuthorized Hello1539R _ = return Authorized
    isAuthorized Hello1540R _ = return Authorized
    isAuthorized Hello1541R _ = return Authorized
    isAuthorized Hello1542R _ = return Authorized
    isAuthorized Hello1543R _ = return Authorized
    isAuthorized Hello1544R _ = return Authorized
    isAuthorized Hello1545R _ = return Authorized
    isAuthorized Hello1546R _ = return Authorized
    isAuthorized Hello1547R _ = return Authorized
    isAuthorized Hello1548R _ = return Authorized
    isAuthorized Hello1549R _ = return Authorized
    isAuthorized Hello1550R _ = return Authorized
    isAuthorized Hello1551R _ = return Authorized
    isAuthorized Hello1552R _ = return Authorized
    isAuthorized Hello1553R _ = return Authorized
    isAuthorized Hello1554R _ = return Authorized
    isAuthorized Hello1555R _ = return Authorized
    isAuthorized Hello1556R _ = return Authorized
    isAuthorized Hello1557R _ = return Authorized
    isAuthorized Hello1558R _ = return Authorized
    isAuthorized Hello1559R _ = return Authorized
    isAuthorized Hello1560R _ = return Authorized
    isAuthorized Hello1561R _ = return Authorized
    isAuthorized Hello1562R _ = return Authorized
    isAuthorized Hello1563R _ = return Authorized
    isAuthorized Hello1564R _ = return Authorized
    isAuthorized Hello1565R _ = return Authorized
    isAuthorized Hello1566R _ = return Authorized
    isAuthorized Hello1567R _ = return Authorized
    isAuthorized Hello1568R _ = return Authorized
    isAuthorized Hello1569R _ = return Authorized
    isAuthorized Hello1570R _ = return Authorized
    isAuthorized Hello1571R _ = return Authorized
    isAuthorized Hello1572R _ = return Authorized
    isAuthorized Hello1573R _ = return Authorized
    isAuthorized Hello1574R _ = return Authorized
    isAuthorized Hello1575R _ = return Authorized
    isAuthorized Hello1576R _ = return Authorized
    isAuthorized Hello1577R _ = return Authorized
    isAuthorized Hello1578R _ = return Authorized
    isAuthorized Hello1579R _ = return Authorized
    isAuthorized Hello1580R _ = return Authorized
    isAuthorized Hello1581R _ = return Authorized
    isAuthorized Hello1582R _ = return Authorized
    isAuthorized Hello1583R _ = return Authorized
    isAuthorized Hello1584R _ = return Authorized
    isAuthorized Hello1585R _ = return Authorized
    isAuthorized Hello1586R _ = return Authorized
    isAuthorized Hello1587R _ = return Authorized
    isAuthorized Hello1588R _ = return Authorized
    isAuthorized Hello1589R _ = return Authorized
    isAuthorized Hello1590R _ = return Authorized
    isAuthorized Hello1591R _ = return Authorized
    isAuthorized Hello1592R _ = return Authorized
    isAuthorized Hello1593R _ = return Authorized
    isAuthorized Hello1594R _ = return Authorized
    isAuthorized Hello1595R _ = return Authorized
    isAuthorized Hello1596R _ = return Authorized
    isAuthorized Hello1597R _ = return Authorized
    isAuthorized Hello1598R _ = return Authorized
    isAuthorized Hello1599R _ = return Authorized
    isAuthorized Hello1600R _ = return Authorized
    isAuthorized Hello1601R _ = return Authorized
    isAuthorized Hello1602R _ = return Authorized
    isAuthorized Hello1603R _ = return Authorized
    isAuthorized Hello1604R _ = return Authorized
    isAuthorized Hello1605R _ = return Authorized
    isAuthorized Hello1606R _ = return Authorized
    isAuthorized Hello1607R _ = return Authorized
    isAuthorized Hello1608R _ = return Authorized
    isAuthorized Hello1609R _ = return Authorized
    isAuthorized Hello1610R _ = return Authorized
    isAuthorized Hello1611R _ = return Authorized
    isAuthorized Hello1612R _ = return Authorized
    isAuthorized Hello1613R _ = return Authorized
    isAuthorized Hello1614R _ = return Authorized
    isAuthorized Hello1615R _ = return Authorized
    isAuthorized Hello1616R _ = return Authorized
    isAuthorized Hello1617R _ = return Authorized
    isAuthorized Hello1618R _ = return Authorized
    isAuthorized Hello1619R _ = return Authorized
    isAuthorized Hello1620R _ = return Authorized
    isAuthorized Hello1621R _ = return Authorized
    isAuthorized Hello1622R _ = return Authorized
    isAuthorized Hello1623R _ = return Authorized
    isAuthorized Hello1624R _ = return Authorized
    isAuthorized Hello1625R _ = return Authorized
    isAuthorized Hello1626R _ = return Authorized
    isAuthorized Hello1627R _ = return Authorized
    isAuthorized Hello1628R _ = return Authorized
    isAuthorized Hello1629R _ = return Authorized
    isAuthorized Hello1630R _ = return Authorized
    isAuthorized Hello1631R _ = return Authorized
    isAuthorized Hello1632R _ = return Authorized
    isAuthorized Hello1633R _ = return Authorized
    isAuthorized Hello1634R _ = return Authorized
    isAuthorized Hello1635R _ = return Authorized
    isAuthorized Hello1636R _ = return Authorized
    isAuthorized Hello1637R _ = return Authorized
    isAuthorized Hello1638R _ = return Authorized
    isAuthorized Hello1639R _ = return Authorized
    isAuthorized Hello1640R _ = return Authorized
    isAuthorized Hello1641R _ = return Authorized
    isAuthorized Hello1642R _ = return Authorized
    isAuthorized Hello1643R _ = return Authorized
    isAuthorized Hello1644R _ = return Authorized
    isAuthorized Hello1645R _ = return Authorized
    isAuthorized Hello1646R _ = return Authorized
    isAuthorized Hello1647R _ = return Authorized
    isAuthorized Hello1648R _ = return Authorized
    isAuthorized Hello1649R _ = return Authorized
    isAuthorized Hello1650R _ = return Authorized
    isAuthorized Hello1651R _ = return Authorized
    isAuthorized Hello1652R _ = return Authorized
    isAuthorized Hello1653R _ = return Authorized
    isAuthorized Hello1654R _ = return Authorized
    isAuthorized Hello1655R _ = return Authorized
    isAuthorized Hello1656R _ = return Authorized
    isAuthorized Hello1657R _ = return Authorized
    isAuthorized Hello1658R _ = return Authorized
    isAuthorized Hello1659R _ = return Authorized
    isAuthorized Hello1660R _ = return Authorized
    isAuthorized Hello1661R _ = return Authorized
    isAuthorized Hello1662R _ = return Authorized
    isAuthorized Hello1663R _ = return Authorized
    isAuthorized Hello1664R _ = return Authorized
    isAuthorized Hello1665R _ = return Authorized
    isAuthorized Hello1666R _ = return Authorized
    isAuthorized Hello1667R _ = return Authorized
    isAuthorized Hello1668R _ = return Authorized
    isAuthorized Hello1669R _ = return Authorized
    isAuthorized Hello1670R _ = return Authorized
    isAuthorized Hello1671R _ = return Authorized
    isAuthorized Hello1672R _ = return Authorized
    isAuthorized Hello1673R _ = return Authorized
    isAuthorized Hello1674R _ = return Authorized
    isAuthorized Hello1675R _ = return Authorized
    isAuthorized Hello1676R _ = return Authorized
    isAuthorized Hello1677R _ = return Authorized
    isAuthorized Hello1678R _ = return Authorized
    isAuthorized Hello1679R _ = return Authorized
    isAuthorized Hello1680R _ = return Authorized
    isAuthorized Hello1681R _ = return Authorized
    isAuthorized Hello1682R _ = return Authorized
    isAuthorized Hello1683R _ = return Authorized
    isAuthorized Hello1684R _ = return Authorized
    isAuthorized Hello1685R _ = return Authorized
    isAuthorized Hello1686R _ = return Authorized
    isAuthorized Hello1687R _ = return Authorized
    isAuthorized Hello1688R _ = return Authorized
    isAuthorized Hello1689R _ = return Authorized
    isAuthorized Hello1690R _ = return Authorized
    isAuthorized Hello1691R _ = return Authorized
    isAuthorized Hello1692R _ = return Authorized
    isAuthorized Hello1693R _ = return Authorized
    isAuthorized Hello1694R _ = return Authorized
    isAuthorized Hello1695R _ = return Authorized
    isAuthorized Hello1696R _ = return Authorized
    isAuthorized Hello1697R _ = return Authorized
    isAuthorized Hello1698R _ = return Authorized
    isAuthorized Hello1699R _ = return Authorized
    isAuthorized Hello1700R _ = return Authorized
    isAuthorized Hello1701R _ = return Authorized
    isAuthorized Hello1702R _ = return Authorized
    isAuthorized Hello1703R _ = return Authorized
    isAuthorized Hello1704R _ = return Authorized
    isAuthorized Hello1705R _ = return Authorized
    isAuthorized Hello1706R _ = return Authorized
    isAuthorized Hello1707R _ = return Authorized
    isAuthorized Hello1708R _ = return Authorized
    isAuthorized Hello1709R _ = return Authorized
    isAuthorized Hello1710R _ = return Authorized
    isAuthorized Hello1711R _ = return Authorized
    isAuthorized Hello1712R _ = return Authorized
    isAuthorized Hello1713R _ = return Authorized
    isAuthorized Hello1714R _ = return Authorized
    isAuthorized Hello1715R _ = return Authorized
    isAuthorized Hello1716R _ = return Authorized
    isAuthorized Hello1717R _ = return Authorized
    isAuthorized Hello1718R _ = return Authorized
    isAuthorized Hello1719R _ = return Authorized
    isAuthorized Hello1720R _ = return Authorized
    isAuthorized Hello1721R _ = return Authorized
    isAuthorized Hello1722R _ = return Authorized
    isAuthorized Hello1723R _ = return Authorized
    isAuthorized Hello1724R _ = return Authorized
    isAuthorized Hello1725R _ = return Authorized
    isAuthorized Hello1726R _ = return Authorized
    isAuthorized Hello1727R _ = return Authorized
    isAuthorized Hello1728R _ = return Authorized
    isAuthorized Hello1729R _ = return Authorized
    isAuthorized Hello1730R _ = return Authorized
    isAuthorized Hello1731R _ = return Authorized
    isAuthorized Hello1732R _ = return Authorized
    isAuthorized Hello1733R _ = return Authorized
    isAuthorized Hello1734R _ = return Authorized
    isAuthorized Hello1735R _ = return Authorized
    isAuthorized Hello1736R _ = return Authorized
    isAuthorized Hello1737R _ = return Authorized
    isAuthorized Hello1738R _ = return Authorized
    isAuthorized Hello1739R _ = return Authorized
    isAuthorized Hello1740R _ = return Authorized
    isAuthorized Hello1741R _ = return Authorized
    isAuthorized Hello1742R _ = return Authorized
    isAuthorized Hello1743R _ = return Authorized
    isAuthorized Hello1744R _ = return Authorized
    isAuthorized Hello1745R _ = return Authorized
    isAuthorized Hello1746R _ = return Authorized
    isAuthorized Hello1747R _ = return Authorized
    isAuthorized Hello1748R _ = return Authorized
    isAuthorized Hello1749R _ = return Authorized
    isAuthorized Hello1750R _ = return Authorized
    isAuthorized Hello1751R _ = return Authorized
    isAuthorized Hello1752R _ = return Authorized
    isAuthorized Hello1753R _ = return Authorized
    isAuthorized Hello1754R _ = return Authorized
    isAuthorized Hello1755R _ = return Authorized
    isAuthorized Hello1756R _ = return Authorized
    isAuthorized Hello1757R _ = return Authorized
    isAuthorized Hello1758R _ = return Authorized
    isAuthorized Hello1759R _ = return Authorized
    isAuthorized Hello1760R _ = return Authorized
    isAuthorized Hello1761R _ = return Authorized
    isAuthorized Hello1762R _ = return Authorized
    isAuthorized Hello1763R _ = return Authorized
    isAuthorized Hello1764R _ = return Authorized
    isAuthorized Hello1765R _ = return Authorized
    isAuthorized Hello1766R _ = return Authorized
    isAuthorized Hello1767R _ = return Authorized
    isAuthorized Hello1768R _ = return Authorized
    isAuthorized Hello1769R _ = return Authorized
    isAuthorized Hello1770R _ = return Authorized
    isAuthorized Hello1771R _ = return Authorized
    isAuthorized Hello1772R _ = return Authorized
    isAuthorized Hello1773R _ = return Authorized
    isAuthorized Hello1774R _ = return Authorized
    isAuthorized Hello1775R _ = return Authorized
    isAuthorized Hello1776R _ = return Authorized
    isAuthorized Hello1777R _ = return Authorized
    isAuthorized Hello1778R _ = return Authorized
    isAuthorized Hello1779R _ = return Authorized
    isAuthorized Hello1780R _ = return Authorized
    isAuthorized Hello1781R _ = return Authorized
    isAuthorized Hello1782R _ = return Authorized
    isAuthorized Hello1783R _ = return Authorized
    isAuthorized Hello1784R _ = return Authorized
    isAuthorized Hello1785R _ = return Authorized
    isAuthorized Hello1786R _ = return Authorized
    isAuthorized Hello1787R _ = return Authorized
    isAuthorized Hello1788R _ = return Authorized
    isAuthorized Hello1789R _ = return Authorized
    isAuthorized Hello1790R _ = return Authorized
    isAuthorized Hello1791R _ = return Authorized
    isAuthorized Hello1792R _ = return Authorized
    isAuthorized Hello1793R _ = return Authorized
    isAuthorized Hello1794R _ = return Authorized
    isAuthorized Hello1795R _ = return Authorized
    isAuthorized Hello1796R _ = return Authorized
    isAuthorized Hello1797R _ = return Authorized
    isAuthorized Hello1798R _ = return Authorized
    isAuthorized Hello1799R _ = return Authorized
    isAuthorized Hello1800R _ = return Authorized
    isAuthorized Hello1801R _ = return Authorized
    isAuthorized Hello1802R _ = return Authorized
    isAuthorized Hello1803R _ = return Authorized
    isAuthorized Hello1804R _ = return Authorized
    isAuthorized Hello1805R _ = return Authorized
    isAuthorized Hello1806R _ = return Authorized
    isAuthorized Hello1807R _ = return Authorized
    isAuthorized Hello1808R _ = return Authorized
    isAuthorized Hello1809R _ = return Authorized
    isAuthorized Hello1810R _ = return Authorized
    isAuthorized Hello1811R _ = return Authorized
    isAuthorized Hello1812R _ = return Authorized
    isAuthorized Hello1813R _ = return Authorized
    isAuthorized Hello1814R _ = return Authorized
    isAuthorized Hello1815R _ = return Authorized
    isAuthorized Hello1816R _ = return Authorized
    isAuthorized Hello1817R _ = return Authorized
    isAuthorized Hello1818R _ = return Authorized
    isAuthorized Hello1819R _ = return Authorized
    isAuthorized Hello1820R _ = return Authorized
    isAuthorized Hello1821R _ = return Authorized
    isAuthorized Hello1822R _ = return Authorized
    isAuthorized Hello1823R _ = return Authorized
    isAuthorized Hello1824R _ = return Authorized
    isAuthorized Hello1825R _ = return Authorized
    isAuthorized Hello1826R _ = return Authorized
    isAuthorized Hello1827R _ = return Authorized
    isAuthorized Hello1828R _ = return Authorized
    isAuthorized Hello1829R _ = return Authorized
    isAuthorized Hello1830R _ = return Authorized
    isAuthorized Hello1831R _ = return Authorized
    isAuthorized Hello1832R _ = return Authorized
    isAuthorized Hello1833R _ = return Authorized
    isAuthorized Hello1834R _ = return Authorized
    isAuthorized Hello1835R _ = return Authorized
    isAuthorized Hello1836R _ = return Authorized
    isAuthorized Hello1837R _ = return Authorized
    isAuthorized Hello1838R _ = return Authorized
    isAuthorized Hello1839R _ = return Authorized
    isAuthorized Hello1840R _ = return Authorized
    isAuthorized Hello1841R _ = return Authorized
    isAuthorized Hello1842R _ = return Authorized
    isAuthorized Hello1843R _ = return Authorized
    isAuthorized Hello1844R _ = return Authorized
    isAuthorized Hello1845R _ = return Authorized
    isAuthorized Hello1846R _ = return Authorized
    isAuthorized Hello1847R _ = return Authorized
    isAuthorized Hello1848R _ = return Authorized
    isAuthorized Hello1849R _ = return Authorized
    isAuthorized Hello1850R _ = return Authorized
    isAuthorized Hello1851R _ = return Authorized
    isAuthorized Hello1852R _ = return Authorized
    isAuthorized Hello1853R _ = return Authorized
    isAuthorized Hello1854R _ = return Authorized
    isAuthorized Hello1855R _ = return Authorized
    isAuthorized Hello1856R _ = return Authorized
    isAuthorized Hello1857R _ = return Authorized
    isAuthorized Hello1858R _ = return Authorized
    isAuthorized Hello1859R _ = return Authorized
    isAuthorized Hello1860R _ = return Authorized
    isAuthorized Hello1861R _ = return Authorized
    isAuthorized Hello1862R _ = return Authorized
    isAuthorized Hello1863R _ = return Authorized
    isAuthorized Hello1864R _ = return Authorized
    isAuthorized Hello1865R _ = return Authorized
    isAuthorized Hello1866R _ = return Authorized
    isAuthorized Hello1867R _ = return Authorized
    isAuthorized Hello1868R _ = return Authorized
    isAuthorized Hello1869R _ = return Authorized
    isAuthorized Hello1870R _ = return Authorized
    isAuthorized Hello1871R _ = return Authorized
    isAuthorized Hello1872R _ = return Authorized
    isAuthorized Hello1873R _ = return Authorized
    isAuthorized Hello1874R _ = return Authorized
    isAuthorized Hello1875R _ = return Authorized
    isAuthorized Hello1876R _ = return Authorized
    isAuthorized Hello1877R _ = return Authorized
    isAuthorized Hello1878R _ = return Authorized
    isAuthorized Hello1879R _ = return Authorized
    isAuthorized Hello1880R _ = return Authorized
    isAuthorized Hello1881R _ = return Authorized
    isAuthorized Hello1882R _ = return Authorized
    isAuthorized Hello1883R _ = return Authorized
    isAuthorized Hello1884R _ = return Authorized
    isAuthorized Hello1885R _ = return Authorized
    isAuthorized Hello1886R _ = return Authorized
    isAuthorized Hello1887R _ = return Authorized
    isAuthorized Hello1888R _ = return Authorized
    isAuthorized Hello1889R _ = return Authorized
    isAuthorized Hello1890R _ = return Authorized
    isAuthorized Hello1891R _ = return Authorized
    isAuthorized Hello1892R _ = return Authorized
    isAuthorized Hello1893R _ = return Authorized
    isAuthorized Hello1894R _ = return Authorized
    isAuthorized Hello1895R _ = return Authorized
    isAuthorized Hello1896R _ = return Authorized
    isAuthorized Hello1897R _ = return Authorized
    isAuthorized Hello1898R _ = return Authorized
    isAuthorized Hello1899R _ = return Authorized
    isAuthorized Hello1900R _ = return Authorized
    isAuthorized Hello1901R _ = return Authorized
    isAuthorized Hello1902R _ = return Authorized
    isAuthorized Hello1903R _ = return Authorized
    isAuthorized Hello1904R _ = return Authorized
    isAuthorized Hello1905R _ = return Authorized
    isAuthorized Hello1906R _ = return Authorized
    isAuthorized Hello1907R _ = return Authorized
    isAuthorized Hello1908R _ = return Authorized
    isAuthorized Hello1909R _ = return Authorized
    isAuthorized Hello1910R _ = return Authorized
    isAuthorized Hello1911R _ = return Authorized
    isAuthorized Hello1912R _ = return Authorized
    isAuthorized Hello1913R _ = return Authorized
    isAuthorized Hello1914R _ = return Authorized
    isAuthorized Hello1915R _ = return Authorized
    isAuthorized Hello1916R _ = return Authorized
    isAuthorized Hello1917R _ = return Authorized
    isAuthorized Hello1918R _ = return Authorized
    isAuthorized Hello1919R _ = return Authorized
    isAuthorized Hello1920R _ = return Authorized
    isAuthorized Hello1921R _ = return Authorized
    isAuthorized Hello1922R _ = return Authorized
    isAuthorized Hello1923R _ = return Authorized
    isAuthorized Hello1924R _ = return Authorized
    isAuthorized Hello1925R _ = return Authorized
    isAuthorized Hello1926R _ = return Authorized
    isAuthorized Hello1927R _ = return Authorized
    isAuthorized Hello1928R _ = return Authorized
    isAuthorized Hello1929R _ = return Authorized
    isAuthorized Hello1930R _ = return Authorized
    isAuthorized Hello1931R _ = return Authorized
    isAuthorized Hello1932R _ = return Authorized
    isAuthorized Hello1933R _ = return Authorized
    isAuthorized Hello1934R _ = return Authorized
    isAuthorized Hello1935R _ = return Authorized
    isAuthorized Hello1936R _ = return Authorized
    isAuthorized Hello1937R _ = return Authorized
    isAuthorized Hello1938R _ = return Authorized
    isAuthorized Hello1939R _ = return Authorized
    isAuthorized Hello1940R _ = return Authorized
    isAuthorized Hello1941R _ = return Authorized
    isAuthorized Hello1942R _ = return Authorized
    isAuthorized Hello1943R _ = return Authorized
    isAuthorized Hello1944R _ = return Authorized
    isAuthorized Hello1945R _ = return Authorized
    isAuthorized Hello1946R _ = return Authorized
    isAuthorized Hello1947R _ = return Authorized
    isAuthorized Hello1948R _ = return Authorized
    isAuthorized Hello1949R _ = return Authorized
    isAuthorized Hello1950R _ = return Authorized
    isAuthorized Hello1951R _ = return Authorized
    isAuthorized Hello1952R _ = return Authorized
    isAuthorized Hello1953R _ = return Authorized
    isAuthorized Hello1954R _ = return Authorized
    isAuthorized Hello1955R _ = return Authorized
    isAuthorized Hello1956R _ = return Authorized
    isAuthorized Hello1957R _ = return Authorized
    isAuthorized Hello1958R _ = return Authorized
    isAuthorized Hello1959R _ = return Authorized
    isAuthorized Hello1960R _ = return Authorized
    isAuthorized Hello1961R _ = return Authorized
    isAuthorized Hello1962R _ = return Authorized
    isAuthorized Hello1963R _ = return Authorized
    isAuthorized Hello1964R _ = return Authorized
    isAuthorized Hello1965R _ = return Authorized
    isAuthorized Hello1966R _ = return Authorized
    isAuthorized Hello1967R _ = return Authorized
    isAuthorized Hello1968R _ = return Authorized
    isAuthorized Hello1969R _ = return Authorized
    isAuthorized Hello1970R _ = return Authorized
    isAuthorized Hello1971R _ = return Authorized
    isAuthorized Hello1972R _ = return Authorized
    isAuthorized Hello1973R _ = return Authorized
    isAuthorized Hello1974R _ = return Authorized
    isAuthorized Hello1975R _ = return Authorized
    isAuthorized Hello1976R _ = return Authorized
    isAuthorized Hello1977R _ = return Authorized
    isAuthorized Hello1978R _ = return Authorized
    isAuthorized Hello1979R _ = return Authorized
    isAuthorized Hello1980R _ = return Authorized
    isAuthorized Hello1981R _ = return Authorized
    isAuthorized Hello1982R _ = return Authorized
    isAuthorized Hello1983R _ = return Authorized
    isAuthorized Hello1984R _ = return Authorized
    isAuthorized Hello1985R _ = return Authorized
    isAuthorized Hello1986R _ = return Authorized
    isAuthorized Hello1987R _ = return Authorized
    isAuthorized Hello1988R _ = return Authorized
    isAuthorized Hello1989R _ = return Authorized
    isAuthorized Hello1990R _ = return Authorized
    isAuthorized Hello1991R _ = return Authorized
    isAuthorized Hello1992R _ = return Authorized
    isAuthorized Hello1993R _ = return Authorized
    isAuthorized Hello1994R _ = return Authorized
    isAuthorized Hello1995R _ = return Authorized
    isAuthorized Hello1996R _ = return Authorized
    isAuthorized Hello1997R _ = return Authorized
    isAuthorized Hello1998R _ = return Authorized
    isAuthorized Hello1999R _ = return Authorized
    isAuthorized Hello2000R _ = return Authorized
    isAuthorized CommentR _ = return Authorized
    isAuthorized HomeR _ = return Authorized
    isAuthorized FaviconR _ = return Authorized
    isAuthorized RobotsR _ = return Authorized
    isAuthorized (StaticR _) _ = return Authorized

    -- the profile route requires that the user is authenticated, so we
    -- delegate to that function
    isAuthorized ProfileR _ = isAuthenticated

    -- This function creates static content files in the static folder
    -- and names them based on a hash of their content. This allows
    -- expiration dates to be set far in the future without worry of
    -- users receiving stale content.
    addStaticContent
        :: Text  -- ^ The file extension
        -> Text -- ^ The MIME content type
        -> LByteString -- ^ The contents of the file
        -> Handler (Maybe (Either Text (Route App, [(Text, Text)])))
    addStaticContent ext mime content = do
        master <- getYesod
        let staticDir = appStaticDir $ appSettings master
        addStaticContentExternal
            minifym
            genFileName
            staticDir
            (StaticR . flip StaticRoute [])
            ext
            mime
            content
      where
        -- Generate a unique filename based on the content itself
        genFileName lbs = "autogen-" ++ base64md5 lbs

    -- What messages should be logged. The following includes all messages when
    -- in development, and warnings and errors in production.
    shouldLogIO :: App -> LogSource -> LogLevel -> IO Bool
    shouldLogIO app _source level =
        return $
        appShouldLogAll (appSettings app)
            || level == LevelWarn
            || level == LevelError

    makeLogger :: App -> IO Logger
    makeLogger = return . appLogger

-- Define breadcrumbs.
instance YesodBreadcrumbs App where
    -- Takes the route that the user is currently on, and returns a tuple
    -- of the 'Text' that you want the label to display, and a previous
    -- breadcrumb route.
    breadcrumb
        :: Route App  -- ^ The route the user is visiting currently.
        -> Handler (Text, Maybe (Route App))
    breadcrumb HomeR = return ("Home", Nothing)
    breadcrumb (AuthR _) = return ("Login", Just HomeR)
    breadcrumb ProfileR = return ("Profile", Just HomeR)
    breadcrumb  _ = return ("home", Nothing)

-- How to run database actions.
instance YesodPersist App where
    type YesodPersistBackend App = SqlBackend
    runDB :: SqlPersistT Handler a -> Handler a
    runDB action = do
        master <- getYesod
        runSqlPool action $ appConnPool master

instance YesodPersistRunner App where
    getDBRunner :: Handler (DBRunner App, Handler ())
    getDBRunner = defaultGetDBRunner appConnPool

instance YesodAuth App where
    type AuthId App = UserId

    -- Where to send a user after successful login
    loginDest :: App -> Route App
    loginDest _ = HomeR
    -- Where to send a user after logout
    logoutDest :: App -> Route App
    logoutDest _ = HomeR
    -- Override the above two destinations when a Referer: header is present
    redirectToReferer :: App -> Bool
    redirectToReferer _ = True

    authenticate :: (MonadHandler m, HandlerSite m ~ App)
                 => Creds App -> m (AuthenticationResult App)
    authenticate creds = liftHandler $ runDB $ do
        x <- getBy $ UniqueUser $ credsIdent creds
        case x of
            Just (Entity uid _) -> return $ Authenticated uid
            Nothing -> Authenticated <$> insert User
                { userIdent = credsIdent creds
                , userPassword = Nothing
                }

    -- You can add other plugins like Google Email, email or OAuth here
    authPlugins :: App -> [AuthPlugin App]
    authPlugins app = [authOpenId Claimed []] ++ extraAuthPlugins
        -- Enable authDummy login if enabled.
        where extraAuthPlugins = [authDummy | appAuthDummyLogin $ appSettings app]

-- | Access function to determine if a user is logged in.
isAuthenticated :: Handler AuthResult
isAuthenticated = do
    muid <- maybeAuthId
    return $ case muid of
        Nothing -> Unauthorized "You must login to access this page"
        Just _ -> Authorized

instance YesodAuthPersist App

-- This instance is required to use forms. You can modify renderMessage to
-- achieve customized and internationalized form validation messages.
instance RenderMessage App FormMessage where
    renderMessage :: App -> [Lang] -> FormMessage -> Text
    renderMessage _ _ = defaultFormMessage

-- Useful when writing code that is re-usable outside of the Handler context.
-- An example is background jobs that send email.
-- This can also be useful for writing code that works across multiple Yesod applications.
instance HasHttpManager App where
    getHttpManager :: App -> Manager
    getHttpManager = appHttpManager

unsafeHandler :: App -> Handler a -> IO a
unsafeHandler = Unsafe.fakeHandlerGetLogger appLogger

-- Note: Some functionality previously present in the scaffolding has been
-- moved to documentation in the Wiki. Following are some hopefully helpful
-- links:
--
-- https://github.com/yesodweb/yesod/wiki/Sending-email
-- https://github.com/yesodweb/yesod/wiki/Serve-static-files-from-a-separate-domain
-- https://github.com/yesodweb/yesod/wiki/i18n-messages-in-the-scaffolding
