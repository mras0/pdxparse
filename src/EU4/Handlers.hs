module EU4.Handlers (
        preStatement
    ,   plainMsg
    ,   msgToPP
    ,   flagText
    ,   isTag
    ,   getProvLoc
    ,   pp_mtth
    ,   compound
    ,   compoundMessage
    ,   compoundMessagePronoun 
    ,   compoundMessageTagged
    ,   allowPronoun
    ,   withLocAtom
    ,   withLocAtom'
    ,   withLocAtom2
    ,   withLocAtomAndIcon
    ,   withLocAtomIcon
    ,   withLocAtomIconEU4Scope
    ,   withLocAtomIconBuilding
    ,   locAtomTagOrProvince
    ,   withProvince
    ,   withNonlocAtom
    ,   withNonlocAtom2
    ,   iconKey
    ,   iconFile
    ,   iconFileB
    ,   iconOrFlag
    ,   tagOrProvince
    ,   tagOrProvinceIcon
    ,   numeric
    ,   numericOrTag
    ,   numericOrTagIcon
    ,   numericIconChange 
    ,   buildingCount
    ,   withFlag 
    ,   withBool
    ,   withFlagOrBool
    ,   withTagOrNumber 
    ,   numericIcon
    ,   numericIconLoc
    ,   numericIconBonus
    ,   numericIconBonusAllowTag
    ,   boolIconLoc
    ,   tryLoc
    ,   tryLocAndIcon
    ,   tryLocAndLocMod
    ,   textValue
    ,   textAtom
    ,   taDescAtomIcon
    ,   taTypeFlag
    ,   simpleEffectNum
    ,   simpleEffectAtom
    ,   ppAiWillDo
    ,   ppAiMod
    ,   factionInfluence
    ,   factionInPower
    ,   addModifier
    ,   addCore
    ,   opinion
    ,   hasOpinion
    ,   spawnRebels
    ,   spawnRebelsSimple
    ,   hasSpawnedRebels
    ,   canSpawnRebels
    ,   triggerEvent
    ,   gainMen
    ,   addCB
    ,   random
    ,   randomList
    ,   defineAdvisor
    ,   defineDynMember
    ,   defineRuler
    ,   defineExiledRuler
    ,   defineHeir
    ,   defineConsort
    ,   buildToForcelimit
    ,   addUnitConstruction
    ,   hasLeaders
    ,   declareWarWithCB
    ,   hasDlc
    ,   hasEstateModifier
    ,   estateInfluenceModifier
    ,   triggerSwitch
    ,   calcTrueIf
    ,   numOwnedProvincesWith
    ,   hreReformLevel
    ,   religionYears
    ,   govtRank
    ,   setGovtRank
    ,   numProvinces
    ,   withFlagOrProvince
    ,   withFlagOrProvinceEU4Scope 
    ,   tradeMod
    ,   isMonth
    ,   range
    ,   area
    ,   dominantCulture
    ,   customTriggerTooltip
    ,   piety
    ,   dynasty
    ,   hasIdea
    ,   trust
    ,   governmentPower
    ,   employedAdvisor
    ,   setVariable
    ,   isInWar
    ,   hasGovermentAttribute
    ,   defineMilitaryLeader
    ,   createMilitaryLeader
    ,   setSavedName
    ,   rhsAlways
    ,   rhsAlwaysYes
    ,   rhsAlwaysEmptyCompound
    ,   privateerPower
    ,   tradingBonus
    ,   hasTradeCompanyInvestment
    ,   tradingPolicyInNode
    ,   randomAdvisor
    ,   killLeader
    ,   addEstateLoyaltyModifier
    ,   exportVariable
    ,   aiAttitude
    ,   estateLandShareEffect
    ,   changeEstateLandShare
    ,   scopeProvince
    ,   personalityAncestor
    ,   hasGreatProject
    ,   hasEstateLedRegency
    ,   changePrice
    ,   hasLeaderWith
    ,   killAdvisorByCategory
    ,   region
    ,   institutionPresence
    ,   expulsionTarget
    ,   spawnScaledRebels
    ,   createIndependentEstate
    ,   numOfReligion
    ,   createSuccessionCrisis
    ,   hasBuildingTrigger
    ,   productionLeader
    ,   addProvinceTriggeredModifier
    ,   hasHeir
    ,   killHeir
    ,   createColonyMissionReward
    ,   hasIdeaGroup
    ,   killUnits
    ,   addBuildingConstruction
    ,   hasGovernmentReforTier
    -- testing
    ,   isPronoun
    ,   flag
    ,   estatePrivilege
    ) where

import Data.Char (toUpper, toLower, isUpper)
import Data.ByteString (ByteString)
import qualified Data.ByteString as B
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Encoding as TE

import Data.HashMap.Strict (HashMap)
import qualified Data.HashMap.Strict as HM
--import Data.Set (Set)
import qualified Data.Set as S
import Data.Trie (Trie)
import qualified Data.Trie as Tr

import qualified Text.PrettyPrint.Leijen.Text as PP

import Data.List (foldl', intersperse)
import Data.Maybe (isJust, isNothing, fromMaybe)

import Control.Applicative (liftA2)
import Control.Arrow (first)
import Control.Monad (foldM, mplus, forM, join, when)
import Data.Foldable (fold)
import Data.Monoid ((<>))

import Abstract -- everything
import Doc (Doc)
import qualified Doc -- everything
import Messages -- everything
import MessageTools (plural, iquotes)
import QQ -- everything
import SettingsTypes ( PPT, IsGameData (..), GameData (..), IsGameState (..), GameState (..)
                     , indentUp, indentDown, withCurrentIndent, withCurrentIndentZero, alsoIndent, alsoIndent'
                     , getGameL10n, getGameL10nIfPresent, getGameL10nDefault, withCurrentFile
                     , unfoldM, unsnoc )
import EU4.Templates
import {-# SOURCE #-} EU4.Common (pp_script, ppMany, ppOne, extractStmt, matchLhsText)
import EU4.Types -- everything

import Debug.Trace

-- | Pretty-print a script statement, wrap it in a @<pre>@ element, and emit a
-- generic message for it at the current indentation level. This is the
-- fallback in case we haven't implemented that particular statement or we
-- failed to understand it.
--
-- Will now try to recurse into nested clauses as they break the wiki layout, and
-- it might be possible to "recover".
preStatement :: (EU4Info g, Monad m) =>
    GenericStatement -> PPT g m IndentedMessages
preStatement [pdx| %lhs = @scr |] = do
    [headerMsg] <- plainMsg $ "<pre>" <> Doc.doc2text (lhs2doc (const "") lhs) <> "</pre>"
    msgs <- ppMany scr
    return (headerMsg : msgs)
preStatement stmt = (:[]) <$> alsoIndent' (preMessage stmt)

-- | Pretty-print a statement and wrap it in a @<pre>@ element.
pre_statement :: GenericStatement -> Doc
pre_statement stmt = "<pre>" <> genericStatement2doc stmt <> "</pre>"

-- | 'Text' version of 'pre_statement'.
pre_statement' :: GenericStatement -> Text
pre_statement' = Doc.doc2text . pre_statement

-- | Pretty-print a script statement, wrap it in a @<pre>@ element, and emit a
-- generic message for it.
preMessage :: GenericStatement -> ScriptMessage
preMessage = MsgUnprocessed
            . TL.toStrict
            . PP.displayT
            . PP.renderPretty 0.8 80 -- Don't use 'Doc.doc2text', because it uses
                                     -- 'Doc.renderCompact' which is not what
                                     -- we want here.
            . pre_statement

-- | Create a generic message from a piece of text. The rendering function will
-- pass this through unaltered.
plainMsg :: (IsGameState (GameState g), Monad m) => Text -> PPT g m IndentedMessages
plainMsg msg = (:[]) <$> (alsoIndent' . MsgUnprocessed $ msg)

msgToPP :: (IsGameState (GameState g), Monad m) => ScriptMessage -> PPT g m IndentedMessages
msgToPP msg = (:[]) <$> alsoIndent' msg

-- Emit icon template.
icon :: Text -> Doc
icon what = case HM.lookup what scriptIconFileTable of
    Just "" -> Doc.strictText $ "[[File:" <> what <> ".png|28px]]" -- shorthand notation
    Just file -> Doc.strictText $ "[[File:" <> file <> ".png|28px]]"
    _ -> template "icon" [HM.lookupDefault what what scriptIconTable, "28px"]
iconText :: Text -> Text
iconText = Doc.doc2text . icon

-- Argument may be a tag or a tagged variable. Emit a flag in the former case,
-- and localize in the latter case.
eflag :: (EU4Info g, Monad m) =>
            Maybe EU4Scope -> Either Text (Text, Text) -> PPT g m (Maybe Text)
eflag expectScope = \case
    Left name -> Just <$> flagText expectScope name
    Right (vartag, var) -> tagged vartag var

-- | Look up the message corresponding to a tagged atom.
--
-- For example, to localize @event_target:some_name@, call
-- @tagged "event_target" "some_name"@.
tagged :: (EU4Info g, Monad m) =>
    Text -> Text -> PPT g m (Maybe Text)
tagged vartag var = case flip Tr.lookup varTags . TE.encodeUtf8 $ vartag of
    Just msg -> Just <$> messageText (msg var)
    Nothing -> return $ Just $ "<tt>" <> vartag <> ":" <> var <> "</tt>" -- just let it pass

flagText :: (EU4Info g, Monad m) =>
    Maybe EU4Scope -> Text -> PPT g m Text
flagText expectScope = fmap Doc.doc2text . flag expectScope

-- Emit an appropriate phrase if the given text is a pronoun, otherwise use the
-- provided localization function.
allowPronoun :: (EU4Info g, Monad m) =>
    Maybe EU4Scope -> (Text -> PPT g m Doc) -> Text -> PPT g m Doc
allowPronoun expectedScope getLoc name =
    if isPronoun name
        then pronoun expectedScope name
        else getLoc name

-- | Emit flag template if the argument is a tag, or an appropriate phrase if
-- it's a pronoun.
flag :: (EU4Info g, Monad m) =>
    Maybe EU4Scope -> Text -> PPT g m Doc
flag expectscope = allowPronoun expectscope $ \name ->
                    template "flag" . (:[]) <$> getGameL10n name

getScopeForPronoun :: (EU4Info g, Monad m) =>
    Text -> PPT g m (Maybe EU4Scope)
getScopeForPronoun = helper . T.toLower where
    helper "this" = getCurrentScope
    helper "root" = getRootScope
    helper "prev" = getPrevScope
    helper "controller" = return (Just EU4Country)
    helper "emperor" = return (Just EU4Country)
    helper "capital" = return (Just EU4Province)
    helper _ = return Nothing

-- | Emit an appropriate phrase for a pronoun.
-- If a scope is passed, that is the type the current command expects. If they
-- don't match, it's a synecdoche; adjust the wording appropriately.
--
-- All handlers in this module that take an argument of type 'Maybe EU4Scope'
-- call this function. Use whichever scope corresponds to what you expect to
-- appear on the RHS. If it can be one of several (e.g. either a country or a
-- province), use EU4From. If it doesn't correspond to any scope, use Nothing.
pronoun :: (EU4Info g, Monad m) =>
    Maybe EU4Scope -> Text -> PPT g m Doc
pronoun expectedScope name = withCurrentFile $ \f -> case T.toLower name of
    "root" -> getRootScope >>= \case -- will need editing
        Just EU4Country
            | expectedScope `matchScope` EU4Country -> message MsgROOTCountry
            | otherwise                             -> message MsgROOTCountryAsOther
        Just EU4Province
            | expectedScope `matchScope` EU4Province -> message MsgROOTProvince
            | expectedScope `matchScope` EU4Country -> message MsgROOTProvinceOwner
            | expectedScope `matchScope` EU4TradeNode -> message MsgROOTTradeNode
            | otherwise                             -> message MsgROOTProvinceAsOther
        -- No synecdoche possible
        Just EU4TradeNode -> message MsgROOTTradeNode
        -- No synecdoche possible
        Just EU4Geographic -> message MsgROOTGeographic
        _ -> return "ROOT"
    "prev" -> --do
--      ss <- getScopeStack
--      traceM (f ++ ": pronoun PREV: scope stack is " ++ show ss)
        getPrevScope >>= \_scope -> case _scope of -- will need editing
            Just EU4Country
                | expectedScope `matchScope` EU4Country -> message MsgPREVCountry
                | otherwise                             -> message MsgPREVCountryAsOther
            Just EU4Province
                | expectedScope `matchScope` EU4Province -> message MsgPREVProvince
                | expectedScope `matchScope` EU4Country -> message MsgPREVProvinceOwner
                | otherwise                             -> message MsgPREVProvinceAsOther
            Just EU4TradeNode -> message MsgPREVTradeNode
            Just EU4Geographic -> message MsgPREVGeographic
            _ -> return "PREV"
    "this" -> getCurrentScope >>= \case -- will need editing
        Just EU4Country
            | expectedScope `matchScope` EU4Country -> message MsgTHISCountry
            | otherwise                             -> message MsgTHISCountryAsOther
        Just EU4Province
            | expectedScope `matchScope` EU4Province -> message MsgTHISProvince
            | expectedScope `matchScope` EU4Country -> message MsgTHISProvinceOwner
            | otherwise                             -> message MsgTHISProvinceAsOther
        Just EU4TradeNode -> message MsgTHISTradeNode
        Just EU4Geographic -> message MsgTHISGeographic
        _ -> return "PREV"
    "controller" -> message MsgController
    "emperor" -> message MsgEmperor
    "original_dynasty" -> message MsgOriginalDynasty
    "historic_dynasty" -> message MsgHistoricDynasty
    "capital" -> message MsgCapital
    "from" -> return "[From]" -- TODO: Handle this properly (if possible)
    _ -> return $ Doc.strictText name -- something else; regurgitate untouched
    where
        Nothing `matchScope` _ = True
        Just expect `matchScope` actual
            | expect == actual = True
            | otherwise        = False

isTag :: Text -> Bool
isTag s = T.length s == 3 && T.all isUpper s

-- Tagged messages
varTags :: Trie (Text -> ScriptMessage)
varTags = Tr.fromList . map (first TE.encodeUtf8) $
    [("event_target", MsgEventTargetVar)
    ]

isPronoun :: Text -> Bool
isPronoun s = T.map toLower s `S.member` pronouns where
    pronouns = S.fromList
        ["root"
        ,"prev"
        ,"this"
        ,"from"
        ,"owner"
        ,"controller"
        ,"emperor"
        ,"original_dynasty"
        ,"historic_dynasty"
        ,"capital"
        ]

-- Get the localization for a province ID, if available.
getProvLoc :: (IsGameData (GameData g), Monad m) =>
    Int -> PPT g m Text
getProvLoc n = do
    let provid_t = T.pack (show n)
    mprovloc <- getGameL10nIfPresent ("PROV" <> provid_t)
    return $ case mprovloc of
        Just loc -> loc <> " (" <> provid_t <> ")"
        _ -> "Province " <> provid_t

-----------------------------------------------------------------
-- Script handlers that should be used directly, not via ppOne --
-----------------------------------------------------------------

-- | Data for @mean_time_to_happen@ clauses
data MTTH = MTTH
        {   mtth_years :: Maybe Int
        ,   mtth_months :: Maybe Int
        ,   mtth_days :: Maybe Int
        ,   mtth_modifiers :: [MTTHModifier]
        } deriving Show
-- | Data for @modifier@ clauses within @mean_time_to_happen@ clauses
data MTTHModifier = MTTHModifier
        {   mtthmod_factor :: Maybe Double
        ,   mtthmod_conditions :: GenericScript
        } deriving Show
-- | Empty MTTH
newMTTH :: MTTH
newMTTH = MTTH Nothing Nothing Nothing []
-- | Empty MTTH modifier
newMTTHMod :: MTTHModifier
newMTTHMod = MTTHModifier Nothing []

-- | Format a @mean_time_to_happen@ clause as wiki text.
pp_mtth :: (EU4Info g, Monad m) => Bool -> GenericScript -> PPT g m Doc
pp_mtth isTriggeredOnly = pp_mtth' . foldl' addField newMTTH
    where
        addField mtth [pdx| years    = !n   |] = mtth { mtth_years = Just n }
        addField mtth [pdx| months   = !n   |] = mtth { mtth_months = Just n }
        addField mtth [pdx| days     = !n   |] = mtth { mtth_days = Just n }
        addField mtth [pdx| modifier = @rhs |] = addMTTHMod mtth rhs
        addField mtth _ = mtth -- unrecognized
        addMTTHMod mtth scr = mtth {
                mtth_modifiers = mtth_modifiers mtth
                                 ++ [foldl' addMTTHModField newMTTHMod scr] } where
            addMTTHModField mtthmod [pdx| factor = !n |]
                = mtthmod { mtthmod_factor = Just n }
            addMTTHModField mtthmod stmt -- anything else is a condition
                = mtthmod { mtthmod_conditions = mtthmod_conditions mtthmod ++ [stmt] }
        pp_mtth' (MTTH myears mmonths mdays modifiers) = do
            modifiers_pp'd <- intersperse PP.line <$> mapM pp_mtthmod modifiers
            let hasYears = isJust myears
                hasMonths = isJust mmonths
                hasDays = isJust mdays
                hasModifiers = not (null modifiers)
            return . mconcat $ (if isTriggeredOnly then [] else
                case myears of
                    Just years ->
                        [PP.int years, PP.space, Doc.strictText $ plural years "year" "years"]
                        ++
                        if hasMonths && hasDays then [",", PP.space]
                        else if hasMonths || hasDays then ["and", PP.space]
                        else []
                    Nothing -> []
                ++
                case mmonths of
                    Just months ->
                        [PP.int months, PP.space, Doc.strictText $ plural months "month" "months"]
                    _ -> []
                ++
                case mdays of
                    Just days ->
                        (if hasYears && hasMonths then ["and", PP.space]
                         else []) -- if years but no months, already added "and"
                        ++
                        [PP.int days, PP.space, Doc.strictText $ plural days "day" "days"]
                    _ -> []
                ) ++
                (if hasModifiers then
                    (if isTriggeredOnly then
                        [PP.line, "'''Weight modifiers'''", PP.line]
                    else
                        [PP.line, "<br/>'''Modifiers'''", PP.line])
                    ++ modifiers_pp'd
                 else [])
        pp_mtthmod (MTTHModifier (Just factor) conditions) =
            case conditions of
                [_] -> do
                    conditions_pp'd <- pp_script conditions
                    return . mconcat $
                        [conditions_pp'd
                        ,PP.enclose ": '''×" "'''" (Doc.pp_float factor)
                        ]
                _ -> do
                    conditions_pp'd <- indentUp (pp_script conditions)
                    return . mconcat $
                        ["*"
                        ,PP.enclose "'''×" "''':" (Doc.pp_float factor)
                        ,PP.line
                        ,conditions_pp'd
                        ]
        pp_mtthmod (MTTHModifier Nothing _)
            = return "(invalid modifier! Bug in extractor?)"

--------------------------------
-- General statement handlers --
--------------------------------

-- | Generic handler for a simple compound statement. Usually you should use
-- 'compoundMessage' instead so the text can be localized.
compound :: (EU4Info g, Monad m) =>
    Text -- ^ Text to use as the block header, without the trailing colon
    -> StatementHandler g m
compound header [pdx| %_ = @scr |]
    = withCurrentIndent $ \_ -> do -- force indent level at least 1
        headerMsg <- plainMsg (header <> ":")
        scriptMsgs <- ppMany scr
        return $ headerMsg ++ scriptMsgs
compound _ stmt = preStatement stmt

-- | Generic handler for a simple compound statement.
compoundMessage :: (EU4Info g, Monad m) =>
    ScriptMessage -- ^ Message to use as the block header
    -> StatementHandler g m
compoundMessage header [pdx| %_ = @scr |]
    = withCurrentIndent $ \i -> do
        script_pp'd <- ppMany scr
        return ((i, header) : script_pp'd)
compoundMessage _ stmt = preStatement stmt

-- | Generic handler for a simple compound statement headed by a pronoun.
compoundMessagePronoun :: (EU4Info g, Monad m) => StatementHandler g m
compoundMessagePronoun stmt@[pdx| $head = @scr |] = withCurrentIndent $ \i -> do
    params <- withCurrentFile $ \f -> case T.toLower head of
        "root" -> do
                newscope <- getRootScope
                return (newscope, case newscope of
                    Just EU4Country -> Just MsgROOTCountry
                    Just EU4Province -> Just MsgROOTProvince
                    Just EU4TradeNode -> Just MsgROOTTradeNode
                    Just EU4Geographic -> Just MsgROOTGeographic
                    _ -> Nothing) -- warning printed below
        "prev" -> do
                newscope <- getPrevScope
                return (newscope, case newscope of
                    Just EU4Country -> Just MsgPREVCountry
                    Just EU4Province -> Just MsgPREVProvince
                    Just EU4TradeNode -> Just MsgPREVTradeNode
                    Just EU4Geographic -> Just MsgPREVGeographic
                    Just EU4From -> Just MsgPREV -- Roll with it
                    _ -> Nothing) -- warning printed below
        "from" -> return (Just EU4From, Just MsgFROM) -- don't know what type this is in general
        _ -> trace (f ++ ": compoundMessagePronoun: don't know how to handle head " ++ T.unpack head)
             $ return (Nothing, undefined)
    case params of
        (Just newscope, Just scopemsg) -> do
            script_pp'd <- scope newscope $ ppMany scr
            return $ (i, scopemsg) : script_pp'd
        _ -> do
            withCurrentFile $ \f -> do
                traceM $ "compoundMessagePronoun: " ++ f ++ ": potentially invalid use of " ++ (T.unpack head) ++ " in " ++ (show stmt)
            preStatement stmt
compoundMessagePronoun stmt = preStatement stmt

-- | Generic handler for a simple compound statement with a tagged header.
compoundMessageTagged :: (EU4Info g, Monad m) =>
    (Text -> ScriptMessage) -- ^ Message to use as the block header
    -> Maybe EU4Scope -- ^ Scope to push on the stack, if any
    -> StatementHandler g m
compoundMessageTagged header mscope stmt@[pdx| $_:$tag = %_ |]
    = (case mscope of
        Just newscope -> scope newscope
        Nothing -> id) $ compoundMessage (header tag) stmt
compoundMessageTagged _ _ stmt = preStatement stmt

-- | Generic handler for a statement whose RHS is a localizable atom.
-- with the ability to transform the localization key
withLocAtom' :: (EU4Info g, Monad m) =>
    (Text -> ScriptMessage) -> (Text -> Text) -> StatementHandler g m
withLocAtom' msg xform [pdx| %_ = ?key |]
    = msgToPP =<< msg <$> getGameL10n (xform key)
withLocAtom' _ _ stmt = preStatement stmt

-- | Generic handler for a statement whose RHS is a localizable atom.
withLocAtom msg stmt = withLocAtom' msg id stmt

-- | Generic handler for a statement whose RHS is a localizable atom and we
-- need a second one (passed to message as first arg).
withLocAtom2 :: (EU4Info g, Monad m) =>
    ScriptMessage
        -> (Text -> Text -> Text -> ScriptMessage)
        -> StatementHandler g m
withLocAtom2 inMsg msg [pdx| %_ = ?key |]
    = msgToPP =<< msg <$> pure key <*> messageText inMsg <*> getGameL10n key
withLocAtom2 _ _ stmt = preStatement stmt

-- | Generic handler for a statement whose RHS is a localizable atom, where we
-- also need an icon.
withLocAtomAndIcon :: (EU4Info g, Monad m) =>
    Text -- ^ icon name - see
         -- <https://www.eu4wiki.com/Template:Icon Template:Icon> on the wiki
        -> (Text -> Text -> ScriptMessage)
        -> StatementHandler g m
withLocAtomAndIcon iconkey msg stmt@[pdx| %_ = $vartag:$var |] = do 
    mtagloc <- tagged vartag var
    case mtagloc of
        Just tagloc -> msgToPP $ msg (iconText iconkey) tagloc
        Nothing -> preStatement stmt
withLocAtomAndIcon iconkey msg [pdx| %_ = ?key |]
    = do what <- Doc.doc2text <$> allowPronoun Nothing (fmap Doc.strictText . getGameL10n) key
         msgToPP $ msg (iconText iconkey) what
withLocAtomAndIcon _ _ stmt = preStatement stmt

-- | Generic handler for a statement whose RHS is a localizable atom that
-- corresponds to an icon.
withLocAtomIcon :: (EU4Info g, Monad m) =>
    (Text -> Text -> ScriptMessage)
        -> StatementHandler g m
withLocAtomIcon msg stmt@[pdx| %_ = ?key |]
    = withLocAtomAndIcon key msg stmt
withLocAtomIcon _ stmt = preStatement stmt

-- | Generic handler for a statement that needs both an atom and an icon, whose
-- meaning changes depending on which scope it's in.
withLocAtomIconEU4Scope :: (EU4Info g, Monad m) =>
    (Text -> Text -> ScriptMessage) -- ^ Message for country scope
        -> (Text -> Text -> ScriptMessage) -- ^ Message for province scope
        -> StatementHandler g m
withLocAtomIconEU4Scope countrymsg provincemsg stmt = do
    thescope <- getCurrentScope
    case thescope of
        Just EU4Country -> withLocAtomIcon countrymsg stmt
        Just EU4Province -> withLocAtomIcon provincemsg stmt
        _ -> preStatement stmt -- others don't make sense

-- | Handler for buildings. Localization needs "building_" prepended. Hack..
withLocAtomIconBuilding :: (EU4Info g, Monad m) =>
    (Text -> Text -> ScriptMessage)
        -> StatementHandler g m
withLocAtomIconBuilding msg stmt@[pdx| %_ = ?key |]
    = do what <- Doc.doc2text <$> allowPronoun Nothing (fmap Doc.strictText . getGameL10n) ("building_" <> key)
         msgToPP $ msg (iconText key) what
withLocAtomIconBuilding _ stmt = preStatement stmt

-- | Generic handler for a statement where the RHS is a localizable atom, but
-- may be replaced with a tag or province to refer synecdochally to the
-- corresponding value.
locAtomTagOrProvince :: (EU4Info g, Monad m) =>
    (Text -> Text -> ScriptMessage) -- ^ Message for atom
        -> (Text -> ScriptMessage) -- ^ Message for synecdoche
        -> StatementHandler g m
locAtomTagOrProvince atomMsg synMsg stmt@[pdx| %_ = $val |] =
    if isTag val || isPronoun val
       then tagOrProvinceIcon synMsg synMsg stmt
       else withLocAtomIcon atomMsg stmt
locAtomTagOrProvince atomMsg synMsg stmt@[pdx| %_ = $vartag:$var |] = do
    mtagloc <- tagged vartag var
    case mtagloc of
        Just tagloc -> msgToPP $ synMsg tagloc
        Nothing -> preStatement stmt
-- Example: religion = variable:From:new_ruler_religion (TODO: Better handling)
locAtomTagOrProvince atomMsg synMsg stmt@[pdx| %_ = $a:$b:$c |] =
    msgToPP $ synMsg ("<tt>" <> a <> ":" <> b <> ":" <> c <> "</tt>")
locAtomTagOrProvince _ _ stmt = preStatement stmt

withProvince :: (EU4Info g, Monad m) =>
    (Text -> ScriptMessage)
        -> StatementHandler g m
withProvince msg stmt@[pdx| %lhs = $vartag:$var |] = do
    mtagloc <- tagged vartag var
    case mtagloc of
        Just tagloc -> msgToPP $ msg tagloc
        Nothing -> preStatement stmt
withProvince msg stmt@[pdx| %lhs = $var |]
    = msgToPP =<< msg . Doc.doc2text <$> pronoun (Just EU4Province) var
withProvince msg [pdx| %lhs = !provid |]
    = msgToPP =<< msg <$> getProvLoc provid
withProvince _ stmt = preStatement stmt

-- As withLocAtom but no l10n.
withNonlocAtom :: (EU4Info g, Monad m) => (Text -> ScriptMessage) -> StatementHandler g m
withNonlocAtom msg [pdx| %_ = ?text |] = msgToPP $ msg text
withNonlocAtom _ stmt = preStatement stmt

-- | As withlocAtom but wth no l10n and an additional bit of text.
withNonlocAtom2 :: (EU4Info g, Monad m) =>
    ScriptMessage
        -> (Text -> Text -> ScriptMessage)
        -> StatementHandler g m
withNonlocAtom2 submsg msg [pdx| %_ = ?txt |] = do
    extratext <- messageText submsg
    msgToPP $ msg extratext txt
withNonlocAtom2 _ _ stmt = preStatement stmt

-- | Table of script atom -> icon key. Only ones that are different are listed.
scriptIconTable :: HashMap Text Text
scriptIconTable = HM.fromList
    [("administrative_ideas", "administrative")
    ,("age_of_absolutism", "age of absolutism")
    ,("age_of_discovery", "age of discovery")
    ,("age_of_reformation", "age of reformation")
    ,("age_of_revolutions", "age of revolutions")
    ,("aristocracy_ideas", "aristocratic")
    ,("army_organizer", "army organizer")
    ,("army_organiser", "army organizer") -- both are used
    ,("army_reformer", "army reformer")
    ,("base_production", "production")
    ,("colonial_governor", "colonial governor")
    ,("defensiveness", "fort defense")
    ,("diplomat", "diplomat_adv")
    ,("diplomatic_ideas", "diplomatic")
    ,("economic_ideas", "economic")
    ,("estate_brahmins", "brahmins")
    ,("estate_burghers", "burghers")
    ,("estate_church", "clergy")
    ,("estate_cossacks", "cossacks")
    ,("estate_dhimmi", "dhimmi")
    ,("estate_jains", "jains")
    ,("estate_maratha", "marathas")
    ,("estate_nobles", "nobles")
    ,("estate_nomadic_tribes", "tribes")
    ,("estate_rajput", "rajputs")
    ,("estate_vaisyas", "vaishyas")
    ,("grand_captain", "grand captain")
    ,("horde_gov_ideas", "horde government")
    ,("indigenous_ideas", "indigenous")
    ,("influence_ideas", "influence")
    ,("innovativeness_ideas", "innovative")
    ,("is_monarch_leader", "ruler general")
    ,("master_of_mint", "master of mint")
    ,("max_accepted_cultures", "max promoted cultures")
    ,("master_recruiter", "master recruiter")
    ,("mesoamerican_religion", "mayan")
    ,("military_engineer", "military engineer")
    ,("natural_scientist", "natural scientist")
    ,("naval_reformer", "naval reformer")
    ,("navy_reformer", "naval reformer") -- these are both used!
    ,("nomad_group", "nomadic")
    ,("norse_pagan_reformed", "norse")
    ,("particularist", "particularists")
    ,("piety", "being pious") -- chosen arbitrarily
    ,("religious_ideas", "religious")
    ,("shamanism", "fetishism") -- religion reused
    ,("local_state_maintenance_modifier", "state maintenance")
    ,("spy_ideas", "espionage")
    ,("tengri_pagan_reformed", "tengri")
    ,("theocracy_gov_ideas", "divine")
    ,("trade_ideas", "trade")
    -- religion
    ,("dreamtime", "alcheringa")
    -- technology
    ,("aboriginal_tech", "aboriginal")
    ,("polynesian_tech", "polynesian")
    -- cults
    ,("buddhism_cult", "buddhadharma")
    ,("central_african_ancestor_cult", "mlira")
    ,("christianity_cult", "christianity")
    ,("cwezi_cult", "cwezi")
    ,("dharmic_cult", "sanatana")
    ,("enkai_cult", "enkai")
    ,("islam_cult", "islam")
    ,("jewish_cult", "haymanot")
    ,("mwari_cult", "mwari")
    ,("norse_cult", "freyja")
    ,("nyame_cult", "nyame")
    ,("roog_cult", "roog")
    ,("south_central_american_cult", "teotl")
    ,("waaq_cult", "waaq")
    ,("yemoja_cult", "yemoja")
    ,("zanahary_cult", "zanahary")
    ,("zoroastrian_cult", "mazdayasna")
    -- religious schools
    ,("hanafi_school", "hanafi")
    ,("hanbali_school", "hanbali")
    ,("maliki_school", "maliki")
    ,("shafii_school", "shafii")
    ,("ismaili_school", "ismaili")
    ,("jafari_school", "jafari")
    ,("zaidi_school", "zaidi")
    -- buildings
    ,("barracks", "western_barracks")
    ,("cathedral", "western_cathedral")
    ,("conscription_center", "western_conscription_center")
    ,("counting_house", "western_counting_house")
    ,("courthouse", "western_courthouse")
    ,("dock", "western_dock")
    ,("drydock", "western_drydock")
    ,("grand_shipyard", "western_grand_shipyard")
    ,("marketplace", "western_marketplace")
    ,("mills", "mill")
    ,("regimental_camp", "western_regimental_camp")
    ,("shipyard", "western_shipyard")
    ,("stock_exchange", "western_stock_exchange")
    ,("temple", "western_temple")
    ,("town_hall", "western_town_hall")
    ,("trade_depot", "western_trade_depot")
    ,("training_fields", "western_training_fields")
    ,("university", "western_university")
    ,("workshop", "western_workshop")
    -- institutions
    ,("new_world_i", "colonialism")
    -- personalities (from ruler_personalities/00_core.txt)
    ,("architectural_visionary_personality", "architectural visionary")
    ,("babbling_buffoon_personality", "babbling buffoon")
    ,("benevolent_personality", "benevolent")
    ,("bold_fighter_personality", "bold fighter")
    ,("calm_personality", "calm")
    ,("careful_personality", "careful")
    ,("charismatic_negotiator_personality", "charismatic negotiator")
    ,("conqueror_personality", "conqueror")
    ,("craven_personality", "craven")
    ,("cruel_personality", "cruel")
    ,("drunkard_personality", "indulgent")
    ,("embezzler_personality", "embezzler")
    ,("entrepreneur_personality", "entrepreneur")
    ,("expansionist_personality", "expansionist")
    ,("fertile_personality", "fertile")
    ,("fierce_negotiator_personality", "fierce negotiator")
    ,("free_thinker_personality", "free thinker")
    ,("greedy_personality", "greedy")
    ,("immortal_personality", "immortal")
    ,("incorruptible_personality", "incorruptible")
    ,("industrious_personality", "industrious")
    ,("infertile_personality", "infertile")
    ,("inspiring_leader_personality", "inspiring leader")
    ,("intricate_web_weaver_personality", "intricate webweaver")
    ,("just_personality", "just")
    ,("kind_hearted_personality", "kind-hearted")
    ,("lawgiver_personality", "lawgiver")
    ,("loose_lips_personality", "loose lips")
    ,("malevolent_personality", "malevolent")
    ,("martial_educator_personality", "martial educator")
    ,("midas_touched_personality", "midas touched")
    ,("naive_personality", "naive enthusiast")
    ,("navigator_personality", "navigator personality")
    ,("obsessive_perfectionist_personality", "obsessive perfectionist")
    ,("pious_personality", "pious")
    ,("righteous_personality", "righteous")
    ,("scholar_personality", "scholar")
    ,("secretive_personality", "secretive")
    ,("silver_tongue_personality", "silver tongue")
    ,("sinner_personality", "sinner")
    ,("strict_personality", "strict")
    ,("tactical_genius_personality", "tactical genius")
    ,("tolerant_personality", "tolerant")
    ,("well_advised_personality", "well advised")
    ,("well_connected_personality", "well connected")
    ,("zealot_personality", "zealot")
    -- AI attitudes
    ,("attitude_allied"      , "ally attitude")
    ,("attitude_defensive"   , "defensive attitude")
    ,("attitude_disloyal"    , "disloyal attitude")
    ,("attitude_domineering" , "domineering attitude")
    ,("attitude_friendly"    , "friendly attitude")
    ,("attitude_hostile"     , "hostile attitude")
    ,("attitude_loyal"       , "loyal attitude")
    ,("attitude_neutral"     , "neutral attitude")
    ,("attitude_outraged"    , "outraged attitude")
    ,("attitude_overlord"    , "overlord attitude")
    ,("attitude_protective"  , "protective attitude")
    ,("attitude_rebellious"  , "rebellious attitude")
    ,("attitude_rivalry"     , "rivalry attitude")
    ,("attitude_threatened"  , "threatened attitude")
    ]

-- | Table of script atom -> file. For things that don't have icons and should instead just
-- show an image. An empty string can be used as a short hand for just appending ".png".
scriptIconFileTable :: HashMap Text Text
scriptIconFileTable = HM.fromList
    [("cost to promote mercantilism", "")
    ,("establish holy order cost", "")
    ,("fleet movement speed", "")
    ,("local state maintenance modifier", "")
    ,("monthly piety accelerator", "")
    -- Trade company investments
    ,("local_quarter", "TC local quarters")
    ,("permanent_quarters", "TC permanent quarters")
    ,("officers_mess", "TC officers mess")
    ,("company_warehouse", "TC warehouse")
    ,("company_depot", "TC depot")
    ,("admiralty", "TC admiralty")
    ,("brokers_office", "TC brokers office")
    ,("brokers_exchange", "TC brokers exchange")
    ,("property_appraiser", "TC property appraiser")
    ,("settlements", "TC settlement")
    ,("district", "TC district")
    ,("townships", "TC township")
    ,("company_administration", "TC company administration")
    ,("military_administration", "TC military administration")
    ,("governor_general_mansion", "TC governor generals mansion")
    -- Disasters
    ,("coup_attempt_disaster", "Coup Attempt")
    -- Holy orders
    ,("dominican_order", "Dominicans")
    ,("franciscan_order", "Franciscans")
    ,("jesuit_order", "Jesuits")
    -- Icons
    ,("icon_climacus"   , "Icon of St. John Climacus")
    ,("icon_eleusa"     , "Icon of Eleusa")
    ,("icon_michael"    , "Icon of St. Michael")
    ,("icon_nicholas"   , "Icon of St. Nicholas")
    ,("icon_pancreator" , "Icon of Christ Pantocrator")
    ]

-- Given a script atom, return the corresponding icon key, if any.
iconKey :: Text -> Maybe Text
iconKey atom = HM.lookup atom scriptIconTable

-- | Table of icon tag to wiki filename. Only those that are different are
-- listed.
iconFileTable :: HashMap Text Text
iconFileTable = HM.fromList
    [("improve relations", "Improve relations")
    ,("ship durability", "Ship durability")
    ,("embargo efficiency", "Embargo efficiency")
    ,("power projection from insults", "Power projection from insults")
    ,("trade company investment cost", "Trade company investment cost")
    ,("missionaries", "Missionaries")
    ,("prestige", "Yearly prestige")
    ,("trade efficiency", "Trade efficiency")
    ,("infantry power", "Infantry combat ability")
    ,("envoy travel time", "Envoy travel time")
    ,("army tradition decay", "Yearly army tradition decay")
    ,("cavalry power", "Cavalry combat ability")
    ,("recover army morale speed", "Recover army morale speed")
    ,("cost of enforcing religion through war", "Cost of enforcing religion through war")
    ,("burghers loyalty", "Burghers loyalty equilibrium")
    ,("heavy ship power", "Heavy ship combat ability")
    ,("blockade impact on siege", "Blockade impact on siege")
    ,("nobility loyalty", "Nobility loyalty equilibrium")
    ,("development cost", "Development cost")
    ,("advisor cost", "Advisor cost")
    ,("missionary strength", "Missionary strength")
    ,("legitimacy", "Legitimacy")
    ,("naval forcelimit", "Naval forcelimit")
    ,("ship cost", "Ship costs")
    ,("siege ability", "Siege ability")
    ,("mercenary cost", "Mercenary cost")
    ,("culture conversion cost", "Culture conversion cost")
    ,("autonomy change cooldown", "Autonomy change cooldown")
    ,("naval attrition", "Naval attrition")
    ,("looting speed", "Looting speed")
    ,("land leader shock", "Land leader shock")
    ,("cost of advisors with ruler's culture", "Cost of advisors with ruler's culture")
    ,("national manpower modifier", "National manpower modifier")
    ,("yearly corruption", "Yearly corruption")
    ,("artillery fire", "Artillery fire")
    ,("free leader pool", "Leader(s) without upkeep")
    ,("regiment cost", "Regiment cost")
    ,("goods produced modifier", "Goods produced modifier")
    ,("unjustified demands", "Unjustified demands")
    ,("province warscore cost", "Province war score cost")
    ,("global heretic missionary strength", "Missionary strength vs heretics")
    ,("trade steering", "Trade steering")
    ,("provincial trade power modifier", "Provincial trade power modifier")
    ,("inflation reduction", "Yearly inflation reduction")
    ,("core creation cost", "Core-creation cost")
    ,("morale of navies", "Morale of navies")
    ,("mandate growth modifier", "Mandate")
    ,("naval maintenance", "Naval maintenance modifier")
    ,("fort maintenance on border with rival", "Fort maintenance on border with rival")
    ,("imperial authority modifier", "Imperial authority modifier")
    ,("interest", "Interest per annum")
    ,("clergy loyalty", "Clergy loyalty equilibrium")
    ,("diplomatic possible policies", "Diplomatic possible policies")
    ,("attrition for enemies", "Attrition for enemies")
    ,("navy tradition", "Navy tradition")
    ,("max promoted cultures", "Max promoted cultures")
    ,("merchant", "Merchants")
    ,("merchants", "Merchants")
    ,("reform desire", "Reform desire")
    ,("church power", "Church power")
    ,("stability cost", "Stability cost modifier")
    ,("imperial authority growth modifier", "Imperial authority growth modifier")
    ,("native assimilation", "Native assimilation")
    ,("embracement cost", "Institution embracement cost")
    ,("mercenary discipline", "Mercenary discipline")
    ,("absolutism", "Absolutism")
    ,("infantry cost", "Infantry cost")
    ,("colonists", "Colonists")
    ,("cost to justify trade conflict", "Justify trade conflict cost")
    ,("naval leader fire", "Naval leader fire")
    ,("years of separatism", "Years of separatism")
    ,("land forcelimit modifier", "Land force limit modifier")
    ,("monthly fervor", "Monthly fervor")
    ,("meritocracy", "Meritocracy")
    ,("land leader fire", "Land leader fire")
    ,("diplomatic annexation cost", "Diplomatic annexation cost")
    ,("advisor pool", "Possible advisors")
    ,("ship disengagement chance", "Ship disengagement chance")
    ,("prestige from land", "Prestige from land battles")
    ,("tolerance heretic", "Tolerance heretic")
    ,("construction time", "Construction time")
    ,("horde unity", "Horde unity")
    ,("burghers influence", "Burghers influence")
    ,("cost to fabricate claims", "Cost to fabricate claims")
    ,("liberty desire in subjects", "Liberty desire in subjects")
    ,("trade power abroad", "Trade power abroad")
    ,("reform progress growth", "Reform progress growth")
    ,("shock damage", "Shock damage")
    ,("diplomatic free policies", "Diplomatic free policies")
    ,("republican tradition", "Republican tradition")
    ,("naval leader shock", "Naval leader shock")
    ,("ship trade power", "Ship trade power")
    ,("manpower recovery speed", "Manpower recovery speed")
    ,("global regiment recruit speed", "Recruitment time")
    ,("sailor maintenance", "Sailor maintenance")
    ,("monarch military skill", "Monarch military skill")
    ,("idea cost", "Idea cost")
    ,("devotion", "Devotion")
    ,("navy tradition decay", "Yearly navy tradition decay")
    ,("cavalry cost", "Cavalry cost")
    ,("national garrison growth", "National garrison growth")
    ,("leader siege", "Leader siege")
    ,("shock damage received", "Shock damage received")
    ,("mercenary manpower", "Mercenary manpower")
    ,("general cost", "General cost")
    ,("cavalry flanking ability", "Cavalry flanking ability")
    ,("military free policies", "Military free policies")
    ,("army tradition from battles", "Army tradition from battles")
    ,("global tariffs", "Global tariffs")
    ,("diplomats", "Diplomat")
    ,("colonial range", "Colonial range")
    ,("global autonomy", "Autonomy")
    ,("marines force limit", "Marines force limit")
    ,("shipbuilding time", "Shipbuilding time")
    ,("blockade efficiency", "Blockade efficiency")
    ,("institution spread", "Institution spread")
    ,("galley cost", "Galley cost")
    ,("maximum revolutionary zeal", "Maximum revolutionary zeal")
    ,("merc maintenance modifier", "Mercenary maintenance")
    ,("vassal forcelimit bonus", "Vassal force limit contribution")
    ,("war exhaustion cost", "Cost of reducing war exhaustion")
    ,("migration cooldown", "Migration cooldown")
    ,("build cost", "Construction cost")
    ,("galley power", "Galley combat ability")
    ,("domestic trade power", "Trade power")
    ,("tribal allegiance", "Yearly tribal _allegiance")
    ,("land fire damage", "Land fire damage")
    ,("light ship power", "Light ship combat ability")
    ,("morale hit when losing a ship", "Morale hit when losing a ship")
    ,("administrative free policies", "Administrative free policies")
    ,("harsh treatment cost", "Harsh treatment cost")
    ,("global settler increase", "Global settler increase")
    ,("global naval engagement", "Global naval engagement")
    ,("caravan power", "Caravan power")
    ,("mil tech cost", "Military technology cost")
    ,("heavy ship cost", "Heavy ship cost")
    ,("papal influence", "Papal influence")
    ,("movement speed", "Movement speed")
    ,("morale of armies", "Morale of armies")
    ,("monthly piety", "Monthly piety")
    ,("native uprising chance", "Native uprising chance")
    ,("female advisor chance", "Female advisor chance")
    ,("liberty desire from subjects development", "Liberty desire from subjects development")
    ,("adm tech cost", "Administrative technology cost")
    ,("artillery power", "Artillery combat ability")
    ,("sailor recovery speed", "Sailor recovery speed")
    ,("missionary maintenance cost", "Missionary maintenance cost")
    ,("land maintenance", "Land maintenance modifier")
    ,("possible policies", "Possible policies")
    ,("tolerance own", "Tolerance of the true faith")
    ,("global spy defence", "Foreign spy detection")
    ,("spy offense", "Spy network construction")
    ,("privateer efficiency", "Privateer efficiency")
    ,("war exhaustion", "War exhaustion")
    ,("reelection cost", "Reelection cost")
    ,("diplomatic reputation", "Diplomatic reputation")
    ,("global trade power", "Trade power")
    ,("army tradition", "Army tradition")
    ,("chance to capture enemy ships", "Chance to capture enemy ships")
    ,("national sailors modifier", "National sailors modifier")
    ,("reinforce speed", "Reinforce speed")
    ,("artillery damage from back row", "Artillery damage from back row")
    ,("tolerance heathen", "Tolerance heathen")
    ,("fort defense", "Fort defense")
    ,("administrative efficiency", "Administrative efficiency")
    ,("flagship cost", "Flagship cost")
    ,("technology cost", "Technology cost")
    ,("prestige decay", "Prestige decay")
    ,("dip tech cost", "Diplomatic technology cost")
    ,("fort maintenance", "Fort maintenance")
    ,("reinforce cost", "Reinforce cost")
    ,("enemy core creation", "Hostile core-creation cost on us")
    ,("state maintenance", "State maintenance")
    ,("possible manchu banners", "Possible Manchu banners")
    ,("global tax modifier", "National tax modifier")
    ,("merchant trade power", "Merchant trade power")
    ,("trade range", "Trade range")
    ,("fire damage received", "Fire damage received")
    ,("income from vassals", "Income from vassals")
    ,("national unrest", "National unrest")
    ,("transport cost", "Transport cost")
    ,("artillery cost", "Artillery cost")
    ,("religious unity", "Religious unity")
    ,("land attrition", "Land attrition")
    ,("light ship cost", "Light ship cost")
    ,("governing capacity modifier", "Governing capacity modifier")
    ,("ae impact", "Aggressive expansion impact")
    ,("minimum autonomy in territories", "Minimum autonomy in territories")
    ,("production efficiency", "Production efficiency")
    ,("diplomatic upkeep", "Diplomatic relations")
    ,("garrison size", "Garrison size")
    ,("cavalry to infantry ratio", "Cavalry to infantry ratio")
    ,("land leader maneuver", "Land leader maneuver")
    ,("monarch diplomatic skill", "Monarch diplomatic skill")
    ,("naval leader maneuver", "Naval leader maneuver")
    ,("discipline", "Discipline")
    ,("chance of new heir", "Chance of new heir")
    ]

-- | Given an {{icon}} key, give the corresponding icon file name.
--
-- Needed for idea groups, which don't use {{icon}}.
iconFile :: Text -> Text
iconFile s = HM.lookupDefault s s iconFileTable
-- | ByteString version of 'iconFile'.
iconFileB :: ByteString -> ByteString
iconFileB = TE.encodeUtf8 . iconFile . TE.decodeUtf8

-- | As generic_icon except
--
-- * say "same as <foo>" if foo refers to a country (in which case, add a flag if possible)
-- * may not actually have an icon (localization file will know if it doesn't)
iconOrFlag :: (EU4Info g, Monad m) =>
    (Text -> Text -> ScriptMessage)
        -> (Text -> ScriptMessage)
        -> Maybe EU4Scope
        -> StatementHandler g m
iconOrFlag _ flagmsg expectScope stmt@[pdx| %_ = $vartag:$var |] = do
    mwhoflag <- eflag expectScope (Right (vartag, var))
    case mwhoflag of
        Just whoflag -> msgToPP . flagmsg $ whoflag
        Nothing -> preStatement stmt
iconOrFlag iconmsg flagmsg expectScope [pdx| $head = $name |] = msgToPP =<< do
    nflag <- flag expectScope name -- laziness means this might not get evaluated
--   when (T.toLower name == "prev") . withCurrentFile $ \f -> do
--       traceM $ f ++ ": iconOrFlag: " ++ T.unpack head ++ " = " ++ T.unpack name
--       ps <- getPrevScope
--       traceM $ "PREV scope is: " ++ show ps
    if isTag name || isPronoun name
        then return . flagmsg . Doc.doc2text $ nflag
        else iconmsg <$> return (iconText . HM.lookupDefault name name $ scriptIconTable)
                     <*> getGameL10n name
iconOrFlag _ _ _ stmt = plainMsg $ pre_statement' stmt

-- | Message with icon and tag.
withFlagAndIcon :: (EU4Info g, Monad m) =>
    Text
        -> (Text -> Text -> ScriptMessage)
        -> Maybe EU4Scope
        -> StatementHandler g m
withFlagAndIcon iconkey flagmsg expectScope stmt@[pdx| %_ = $vartag:$var |] = do
    mwhoflag <- eflag expectScope (Right (vartag, var))
    case mwhoflag of
        Just whoflag -> msgToPP . flagmsg (iconText iconkey) $ whoflag
        Nothing -> preStatement stmt
withFlagAndIcon iconkey flagmsg expectScope [pdx| %_ = $name |] = msgToPP =<< do
    nflag <- flag expectScope name
    return . flagmsg (iconText iconkey) . Doc.doc2text $ nflag
withFlagAndIcon _ _ _ stmt = plainMsg $ pre_statement' stmt

-- | Handler for statements where RHS is a tag or province id.
tagOrProvince :: (EU4Info g, Monad m) =>
    (Text -> ScriptMessage)
        -> (Text -> ScriptMessage)
        -> Maybe EU4Scope
        -> StatementHandler g m
tagOrProvince tagmsg _ expectScope stmt@[pdx| %_ = $vartag:$var |] = do
    mwhoflag <- eflag expectScope (Right (vartag, var))
    case mwhoflag of
        Just whoflag -> msgToPP $ tagmsg whoflag
        Nothing -> preStatement stmt
tagOrProvince tagmsg provmsg expectScope stmt@[pdx| %_ = ?!eobject |]
    = msgToPP =<< case eobject of
            Just (Right tag) -> do
                tagflag <- flag expectScope tag
                return . tagmsg . Doc.doc2text $ tagflag
            Just (Left provid) -> do -- is a province id
                prov_loc <- getProvLoc provid
                return . provmsg $ prov_loc
            Nothing -> return (preMessage stmt)
tagOrProvince _ _ _ stmt = preStatement stmt

tagOrProvinceIcon :: (EU4Info g, Monad m) =>
    (Text -> ScriptMessage)
        -> (Text -> ScriptMessage)
        -> StatementHandler g m
tagOrProvinceIcon tagmsg provmsg stmt@[pdx| $head = ?!eobject |]
    = msgToPP =<< case eobject of
            Just (Right tag) -> do -- string: is a tag or pronoun
--              when (T.toLower tag == "prev") . withCurrentFile $ \f -> do
--                  traceM $ f ++ ": tagOrProvinceIcon: " ++ T.unpack head ++ " = " ++ T.unpack tag
--                  ps <- getPrevScope
--                  traceM $ "PREV scope is: " ++ show ps
                tagflag <- flag Nothing tag
                return . tagmsg . Doc.doc2text $ tagflag
            Just (Left provid) -> do -- is a province id
                prov_loc <- getProvLoc provid
                return . provmsg $ prov_loc
            Nothing -> return (preMessage stmt)
tagOrProvinceIcon _ _ stmt = preStatement stmt

-- TODO (if necessary): allow operators other than = and pass them to message
-- handler
-- | Handler for numeric statements.
numeric :: (IsGameState (GameState g), Monad m) =>
    (Double -> ScriptMessage)
        -> StatementHandler g m
numeric msg [pdx| %_ = !n |] = msgToPP $ msg n
numeric _ stmt = plainMsg $ pre_statement' stmt

-- | Handler for statements where the RHS is either a number or a tag.
numericOrTag :: (EU4Info g, Monad m) =>
    (Double -> ScriptMessage)
        -> (Text -> ScriptMessage)
        -> StatementHandler g m
numericOrTag numMsg tagMsg stmt@[pdx| %_ = %rhs |] = msgToPP =<<
    case floatRhs rhs of
        Just n -> return $ numMsg n
        Nothing -> case textRhs rhs of
            Just t -> do -- assume it's a country
                tflag <- flag (Just EU4Country) t
                return $ tagMsg (Doc.doc2text tflag)
            Nothing -> return (preMessage stmt)
numericOrTag _ _ stmt = preStatement stmt

-- | Handler for statements where the RHS is either a number or a tag, that
-- also require an icon.
numericOrTagIcon :: (EU4Info g, Monad m) =>
    Text
        -> (Text -> Double -> ScriptMessage)
        -> (Text -> Text -> ScriptMessage)
        -> StatementHandler g m
numericOrTagIcon icon numMsg tagMsg stmt@[pdx| %_ = %rhs |] = msgToPP =<<
    case floatRhs rhs of
        Just n -> return $ numMsg (iconText icon) n
        Nothing -> case textRhs rhs of
            Just t -> do -- assume it's a country
                tflag <- flag (Just EU4Country) t
                return $ tagMsg (iconText icon) (Doc.doc2text tflag)
            Nothing -> return (preMessage stmt)
numericOrTagIcon _ _ _ stmt = preStatement stmt

-- | Handler for a statement referring to a country. Use a flag.
withFlag :: (EU4Info g, Monad m) =>
    (Text -> ScriptMessage) -> StatementHandler g m
withFlag msg stmt@[pdx| %_ = $vartag:$var |] = do
    mwhoflag <- eflag (Just EU4Country) (Right (vartag, var))
    case mwhoflag of
        Just whoflag -> msgToPP . msg $ whoflag
        Nothing -> preStatement stmt
withFlag msg [pdx| %_ = $who |] = do
    whoflag <- flag (Just EU4Country) who
    msgToPP . msg . Doc.doc2text $ whoflag
withFlag _ stmt = preStatement stmt

-- | Handler for yes-or-no statements.
withBool :: (EU4Info g, Monad m) =>
    (Bool -> ScriptMessage)
        -> StatementHandler g m
withBool msg stmt = do
    fullmsg <- withBool' msg stmt
    maybe (preStatement stmt)
          return
          fullmsg

-- | Helper for 'withBool'.
withBool' :: (EU4Info g, Monad m) =>
    (Bool -> ScriptMessage)
        -> GenericStatement
        -> PPT g m (Maybe IndentedMessages)
withBool' msg [pdx| %_ = ?yn |] | T.map toLower yn `elem` ["yes","no","false"]
    = fmap Just . msgToPP $ case T.toCaseFold yn of
        "yes" -> msg True
        "no"  -> msg False
        "false" -> msg False
        _     -> error "impossible: withBool matched a string that wasn't yes, no or false"
withBool' _ _ = return Nothing

-- | Like numericIconLoc, but for booleans
boolIconLoc :: (EU4Info g, Monad m) =>
    Text
        -> Text
        -> (Text -> Text -> Bool -> ScriptMessage)
        -> StatementHandler g m
boolIconLoc the_icon what msg stmt
    = do
        whatloc <- getGameL10n what
        res <- withBool' (msg (iconText the_icon) whatloc) stmt
        maybe (preStatement stmt)
              return
              res

-- | Handler for statements whose RHS may be "yes"/"no" or a tag.
withFlagOrBool :: (EU4Info g, Monad m) =>
    (Bool -> ScriptMessage)
        -> (Text -> ScriptMessage)
        -> StatementHandler g m
withFlagOrBool bmsg _ [pdx| %_ = yes |] = msgToPP (bmsg True)
withFlagOrBool bmsg _ [pdx| %_ = no  |]  = msgToPP (bmsg False)
withFlagOrBool _ tmsg stmt = withFlag tmsg stmt

-- | Handler for statements whose RHS is a number OR a tag/prounoun, with icon
withTagOrNumber :: (EU4Info g, Monad m) =>
    Text
        -> (Text -> Double -> ScriptMessage)
        -> (Text -> Text -> ScriptMessage)
        -> StatementHandler g m
withTagOrNumber iconkey numMsg _ [pdx| %_ = !num |]
    = msgToPP $ numMsg (iconText iconkey) num
withTagOrNumber iconkey _ tagMsg scr@[pdx| %_ = $_ |]
    = withFlagAndIcon iconkey tagMsg (Just EU4Country) scr
withTagOrNumber  _ _ _ stmt = plainMsg $ pre_statement' stmt

-- | Handler for statements that have a number and an icon.
numericIcon :: (IsGameState (GameState g), Monad m) =>
    Text
        -> (Text -> Double -> ScriptMessage)
        -> StatementHandler g m
numericIcon the_icon msg [pdx| %_ = !amt |]
    = msgToPP $ msg (iconText the_icon) amt
numericIcon _ _ stmt = plainMsg $ pre_statement' stmt

-- | Handler for statements that have a number and an icon, plus a fixed
-- localizable atom.
numericIconLoc :: (IsGameState (GameState g), IsGameData (GameData g), Monad m) =>
    Text
        -> Text
        -> (Text -> Text -> Double -> ScriptMessage)
        -> StatementHandler g m
numericIconLoc the_icon what msg [pdx| %_ = !amt |]
    = do whatloc <- getGameL10n what
         msgToPP $ msg (iconText the_icon) whatloc amt
numericIconLoc _ _ _ stmt = plainMsg $ pre_statement' stmt

-- | Handler for statements that have a number and an icon, whose meaning
-- differs depending on what scope it's in.
numericIconBonus :: (EU4Info g, Monad m) =>
    Text
        -> (Text -> Double -> ScriptMessage) -- ^ Message for country / other scope
        -> (Text -> Double -> ScriptMessage) -- ^ Message for bonus scope
        -> StatementHandler g m
numericIconBonus the_icon plainmsg yearlymsg [pdx| %_ = !amt |]
    = do
        mscope <- getCurrentScope
        let icont = iconText the_icon
            yearly = msgToPP $ yearlymsg icont amt
        case mscope of
            Nothing -> yearly -- ideas / bonuses
            Just thescope -> case thescope of
                EU4Bonus -> yearly
                _ -> -- act as though it's country for all others
                    msgToPP $ plainmsg icont amt
numericIconBonus _ _ _ stmt = plainMsg $ pre_statement' stmt


-- | Like numericIconBonus but allow rhs to be a tag/scope (used for e.g. "prestige")
numericIconBonusAllowTag :: (EU4Info g, Monad m) =>
    Text
        -> (Text -> Double -> ScriptMessage) -- ^ Message for country / other scope
        -> (Text -> Text -> ScriptMessage)   -- ^ Message for tag/scope
        -> (Text -> Double -> ScriptMessage) -- ^ Message for bonus scope
        -> StatementHandler g m
numericIconBonusAllowTag the_icon plainmsg plainAsMsg yearlymsg stmt@[pdx| %_ = $what |]
    = do
        whatLoc <- flagText (Just EU4Country) what
        msgToPP $ plainAsMsg (iconText the_icon) whatLoc
numericIconBonusAllowTag the_icon plainmsg _ yearlymsg stmt
    = numericIconBonus the_icon plainmsg yearlymsg stmt

-- | Handler for values that use a different message and icon depending on
-- whether the value is positive or negative.
numericIconChange :: (EU4Info g, Monad m) =>
    Text        -- ^ Icon for negative values
        -> Text -- ^ Icon for positive values
        -> (Text -> Double -> ScriptMessage) -- ^ Message for negative values
        -> (Text -> Double -> ScriptMessage) -- ^ Message for positive values
        -> StatementHandler g m
numericIconChange negicon posicon negmsg posmsg [pdx| %_ = !amt |]
    = if amt < 0
        then msgToPP $ negmsg (iconText negicon) amt
        else msgToPP $ posmsg (iconText posicon) amt
numericIconChange _ _ _ _ stmt = plainMsg $ pre_statement' stmt


-- | Handler for e.g. temple = X
buildingCount :: (EU4Info g, Monad m) => StatementHandler g m
buildingCount [pdx| $building = !count |] = do
    what <- getGameL10n ("building_" <> building)
    msgToPP $ MsgHasNumberOfBuildingType (iconText building) what count
buildingCount stmt = preStatement stmt

----------------------
-- Text/value pairs --
----------------------

-- $textvalue
-- This is for statements of the form
--      head = {
--          what = some_atom
--          value = 3
--      }
-- e.g.
--      num_of_religion = {
--          religion = catholic
--          value = 0.5
--      }
-- There are several statements of this form, but with different "what" and
-- "value" labels, so the first two parameters say what those label are.
--
-- There are two message parameters, one for value < 1 and one for value >= 1.
-- In the example num_of_religion, value is interpreted as a percentage of
-- provinces if less than 1, or a number of provinces otherwise. These require
-- rather different messages.
--
-- We additionally attempt to localize the RHS of "what". If it has no
-- localization string, it gets wrapped in a @<tt>@ element instead.

-- convenience synonym
tryLoc :: (IsGameData (GameData g), Monad m) => Text -> PPT g m (Maybe Text)
tryLoc = getGameL10nIfPresent

-- | Get icon and localization for the atom given. Return @mempty@ if there is
-- no icon, and wrapped in @<tt>@ tags if there is no localization.
tryLocAndIcon :: (IsGameData (GameData g), Monad m) => Text -> PPT g m (Text,Text)
tryLocAndIcon atom = do
    loc <- tryLoc atom
    return (maybe mempty id (Just (iconText atom)),
            maybe ("<tt>" <> atom <> "</tt>") id loc)

-- | Same as tryLocAndIcon but for global modifiers
tryLocAndLocMod :: (IsGameData (GameData g), Monad m) => Text -> PPT g m (Text,Text)
tryLocAndLocMod atom = do
    loc <- tryLoc (HM.lookupDefault atom atom locTable)
    when (isNothing loc) (traceM $ "tryLocAndLocMod: Localization failed for modifier: " ++ (T.unpack atom))
    return (maybe mempty id (Just (iconText atom)),
            maybe ("<tt>" <> atom <> "</tt>") id loc)
    where
        locTable :: HashMap Text Text
        locTable = HM.fromList
            [("female_advisor_chance", "MODIFIER_FEMALE_ADVISOR_CHANCE")
            ,("discipline", "MODIFIER_DISCIPLINE")
            ,("cavalry_power", "CAVALRY_POWER")
            ,("missionaries" , "MISSIONARY_CONSTRUCTIONS") -- ?
            ,("ship_durability", "MODIFIER_SHIP_DURABILITY")
            ,("tolerance_heathen", "MODIFIER_TOLERANCE_HEATHEN")
            ]

data TextValue = TextValue
        {   tv_what :: Maybe Text
        ,   tv_value :: Maybe Double
        }
newTV :: TextValue
newTV = TextValue Nothing Nothing

parseTV whatlabel vallabel scr = foldl' addLine newTV scr
    where
        addLine :: TextValue -> GenericStatement -> TextValue
        addLine tv [pdx| $label = ?what |] | label == whatlabel
            = tv { tv_what = Just what }
        addLine tv [pdx| $label = !val |] | label == vallabel
            = tv { tv_value = Just val }
        addLine nor _ = nor

textValue :: forall g m. (EU4Info g, Monad m) =>
    Text                                             -- ^ Label for "what"
        -> Text                                      -- ^ Label for "how much"
        -> (Text -> Text -> Double -> ScriptMessage) -- ^ Message constructor, if abs value < 1
        -> (Text -> Text -> Double -> ScriptMessage) -- ^ Message constructor, if abs value >= 1
        -> (Text -> PPT g m (Text, Text)) -- ^ Action to localize and get icon (applied to RHS of "what")
        -> StatementHandler g m
textValue whatlabel vallabel smallmsg bigmsg loc stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_tv (parseTV whatlabel vallabel scr)
    where
        pp_tv :: TextValue -> PPT g m ScriptMessage
        pp_tv tv = case (tv_what tv, tv_value tv) of
            (Just what, Just value) -> do
                (what_icon, what_loc) <- loc what
                return $ (if abs value < 1 then smallmsg else bigmsg) what_icon what_loc value
            _ -> return $ preMessage stmt
textValue _ _ _ _ _ stmt = preStatement stmt

-- | Statements of the form
-- @
--      has_trade_modifier = {
--          who = ROOT
--          name = merchant_recalled
--      }
-- @
data TextAtom = TextAtom
        {   ta_what :: Maybe Text
        ,   ta_atom :: Maybe Text
        }
newTA :: TextAtom
newTA = TextAtom Nothing Nothing

parseTA whatlabel atomlabel scr = (foldl' addLine newTA scr)
    where
        addLine :: TextAtom -> GenericStatement -> TextAtom
        addLine ta [pdx| $label = ?what |]
            | label == whatlabel
            = ta { ta_what = Just what }
        addLine ta [pdx| $label = ?at |]
            | label == atomlabel
            = ta { ta_atom = Just at }
        addLine ta scr = (trace ("parseTA: Ignoring " ++ show scr)) $ ta


textAtom :: forall g m. (EU4Info g, Monad m) =>
    Text -- ^ Label for "what" (e.g. "who")
        -> Text -- ^ Label for atom (e.g. "name")
        -> (Text -> Text -> Text -> ScriptMessage) -- ^ Message constructor
        -> (Text -> PPT g m (Maybe Text)) -- ^ Action to localize, get icon, etc. (applied to RHS of "what")
        -> StatementHandler g m
textAtom whatlabel atomlabel msg loc stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_ta (parseTA whatlabel atomlabel scr)
    where
        pp_ta :: TextAtom -> PPT g m ScriptMessage
        pp_ta ta = case (ta_what ta, ta_atom ta) of
            (Just what, Just atom) -> do
                mwhat_loc <- loc what
                atom_loc <- getGameL10n atom
                let what_icon = iconText what
                    what_loc = fromMaybe ("<tt>" <> what <> "</tt>") mwhat_loc
                return $ msg what_icon what_loc atom_loc
            _ -> return $ preMessage stmt
textAtom _ _ _ _ stmt = preStatement stmt

taDescAtomIcon :: forall g m. (EU4Info g, Monad m) =>
    Text -> Text ->
    (Text -> Text -> Text -> ScriptMessage) -> StatementHandler g m
taDescAtomIcon tDesc tAtom msg stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_lai (parseTA tDesc tAtom scr)
    where
        pp_lai :: TextAtom -> PPT g m ScriptMessage
        pp_lai ta = case (ta_what ta, ta_atom ta) of
            (Just desc, Just atom) -> do
                descLoc <- getGameL10n desc
                atomLoc <- getGameL10n (T.toUpper atom) -- XXX: why does it seem to necessary to use toUpper here?
                return $ msg descLoc (iconText atom) atomLoc
            _ -> return $ preMessage stmt
taDescAtomIcon _ _ _ stmt = preStatement stmt


taTypeFlag :: forall g m. (EU4Info g, Monad m) => Text -> Text -> (Text -> Text -> ScriptMessage) -> StatementHandler g m
taTypeFlag tType tFlag msg stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_tf (parseTA tType tFlag scr)
    where
        pp_tf :: TextAtom -> PPT g m ScriptMessage
        pp_tf ta = case (ta_what ta, ta_atom ta) of
            (Just typ, Just flag) -> do
                typeLoc <- getGameL10n typ
                flagLoc <- flagText (Just EU4Country) flag
                return $ msg typeLoc flagLoc
            _ -> return $ preMessage stmt
taTypeFlag _ _ _ stmt = preStatement stmt

-- | Helper for effects, where the argument is a single statement in a clause
-- E.g. generate_traitor_advisor_effect

getEffectArg :: Text -> GenericStatement -> Maybe (Rhs () ())
getEffectArg tArg stmt@[pdx| %_ = @scr |] = case scr of
        [[pdx| $arg = %val |]] | T.toLower arg == tArg -> Just val
        _ -> Nothing
getEffectArg _ _ = Nothing

simpleEffectNum :: forall g m. (EU4Info g, Monad m) => Text ->  (Double -> ScriptMessage) -> StatementHandler g m
simpleEffectNum tArg msg stmt =
    case getEffectArg tArg stmt of
        Just (FloatRhs num) -> msgToPP (msg num)
        Just (IntRhs num) -> msgToPP (msg (fromIntegral num))
        _ -> (trace $ "warning: Not handled by simpleEffectNum: " ++ (show stmt)) $ preStatement stmt

simpleEffectAtom :: forall g m. (EU4Info g, Monad m) => Text -> (Text -> Text -> ScriptMessage) -> StatementHandler g m
simpleEffectAtom tArg msg stmt =
    case getEffectArg tArg stmt of
        Just (GenericRhs atom _) -> do
            loc <- getGameL10n atom
            msgToPP $ msg (iconText atom) loc
        _ -> (trace $ "warning: Not handled by simpleEffectAtom: " ++ (show stmt)) $ preStatement stmt

-- AI decision factors

-- | Extract the appropriate message(s) from an @ai_will_do@ clause.
ppAiWillDo :: (EU4Info g, Monad m) => AIWillDo -> PPT g m IndentedMessages
ppAiWillDo (AIWillDo mbase mods) = do
    mods_pp'd <- fold <$> traverse ppAiMod mods
    let baseWtMsg = case mbase of
            Nothing -> MsgNoBaseWeight
            Just base -> MsgAIBaseWeight base
    iBaseWtMsg <- msgToPP baseWtMsg
    return $ iBaseWtMsg ++ mods_pp'd

-- | Extract the appropriate message(s) from a @modifier@ section within an
-- @ai_will_do@ clause.
ppAiMod :: (EU4Info g, Monad m) => AIModifier -> PPT g m IndentedMessages
ppAiMod (AIModifier (Just multiplier) triggers) = do
    triggers_pp'd <- ppMany triggers
    case triggers_pp'd of
        [(i, triggerMsg)] -> do
            triggerText <- messageText triggerMsg
            return [(i, MsgAIFactorOneline triggerText multiplier)]
        _ -> withCurrentIndentZero $ \i -> return $
            (i, MsgAIFactorHeader multiplier)
            : map (first succ) triggers_pp'd -- indent up
ppAiMod (AIModifier Nothing _) =
    plainMsg "(missing multiplier for this factor)"

-- | Verify assumption about rhs
rhsAlways :: (EU4Info g, Monad m) => Text -> ScriptMessage -> StatementHandler g m
rhsAlways assumedRhs msg [pdx| %_ = ?rhs |] | T.toLower rhs == assumedRhs = msgToPP $ msg
rhsAlways _ _ stmt = (trace $ "Expectation is wrong in statement " ++ show stmt) $ preStatement stmt

rhsAlwaysYes :: (EU4Info g, Monad m) => ScriptMessage -> StatementHandler g m
rhsAlwaysYes = rhsAlways "yes"

rhsAlwaysEmptyCompound :: (EU4Info g, Monad m) => ScriptMessage -> StatementHandler g m
rhsAlwaysEmptyCompound msg stmt@(Statement _ OpEq (CompoundRhs [])) = msgToPP $ msg
rhsAlwaysEmptyCompound _ stmt = (trace $ "Expectation is wrong in statement " ++ show stmt) $ preStatement stmt

---------------------------------
-- Specific statement handlers --
---------------------------------

-- Factions.
-- We want to use the faction influence icons, not the faction icons, so
-- textValue unfortunately doesn't work here.

-- | Convert the atom used in scripts for a faction to the corresponding icon
-- key for its influence.
facInfluence_iconkey :: Text -> Maybe Text
facInfluence_iconkey fac = case fac of
        -- Celestial empire
        "enuchs" {- sic -} -> Just "eunuchs influence"
        "temples"          -> Just "temples influence"
        "bureaucrats"      -> Just "bureaucrats influence"
        -- Merchant republic
        "mr_aristocrats"   -> Just "aristocrats influence"
        "mr_guilds"        -> Just "guilds influence"
        "mr_traders"       -> Just "traders influence"
        -- Revolutionary republic
        "rr_jacobins"      -> Just "jacobin influence"
        "rr_royalists"     -> Just "imperial influence"
        "rr_girondists"    -> Just "girondist influence"
        _ {- unknown -}    -> Nothing

-- | Convert the atom used in scripts for a faction to the corresponding icon
-- key.
fac_iconkey :: Text -> Maybe Text
fac_iconkey fac = case fac of
        -- Celestial empire
        "enuchs" {- sic -} -> Just "eunuchs"
        "temples"          -> Just "temples"
        "bureaucrats"      -> Just "bureaucrats"
        -- Merchant republic
        "mr_aristocrats"   -> Just "aristocrats"
        "mr_guilds"        -> Just "guilds"
        "mr_traders"       -> Just "traders"
        -- Revolutionary republic
        "rr_jacobins"      -> Just "jacobins"
        "rr_royalists"     -> Just "imperials"
        "rr_girondists"    -> Just "girondists"
        _ {- unknown -}    -> Nothing

data FactionInfluence = FactionInfluence {
        faction :: Maybe Text
    ,   influence :: Maybe Double
    }
-- | Empty 'FactionInfluence'
newInfluence :: FactionInfluence
newInfluence = FactionInfluence Nothing Nothing
-- | Handler for faction influence.
factionInfluence :: (EU4Info g, Monad m) =>
                     (Text -> Text -> Double -> ScriptMessage) -> StatementHandler g m
factionInfluence msg stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_influence (foldl' addField newInfluence scr)
    where
        pp_influence inf = case (faction inf, influence inf) of
            (Just fac, Just infl) ->
                let fac_icon = maybe ("<!-- " <> fac <> " -->") iconText (facInfluence_iconkey fac)
                in do
                    fac_loc <- getGameL10n fac
                    return $ msg fac_icon fac_loc infl
            _ -> return $ preMessage stmt
        addField :: FactionInfluence -> GenericStatement -> FactionInfluence
        addField inf [pdx| faction   = ?fac |] = inf { faction = Just fac }
        addField inf [pdx| influence = !amt |] = inf { influence = Just amt }
        addField inf _ = inf -- unknown statement
factionInfluence _ stmt = preStatement stmt

-- | Handler for trigger checking which faction is in power.
factionInPower :: (EU4Info g, Monad m) => StatementHandler g m
factionInPower [pdx| %_ = ?fac |] | Just facKey <- fac_iconkey fac
    = do fac_loc <- getGameL10n fac
         msgToPP $ MsgFactionInPower (iconText facKey) fac_loc
factionInPower stmt = preStatement stmt

-- Modifiers

data AddModifier = AddModifier {
        amod_name :: Maybe Text
    ,   amod_key :: Maybe Text
    ,   amod_who :: Maybe Text
    ,   amod_duration :: Maybe Double
    ,   amod_power :: Maybe Double
    } deriving Show
newAddModifier :: AddModifier
newAddModifier = AddModifier Nothing Nothing Nothing Nothing Nothing

addModifierLine :: AddModifier -> GenericStatement -> AddModifier
addModifierLine apm [pdx| name     = ?name     |] = apm { amod_name = Just name }
addModifierLine apm [pdx| key      = ?key      |] = apm { amod_key = Just key }
addModifierLine apm [pdx| who      = ?tag      |] = apm { amod_who = Just tag }
addModifierLine apm [pdx| duration = !duration |] = apm { amod_duration = Just duration }
addModifierLine apm [pdx| power    = !power    |] = apm { amod_power = Just power }
addModifierLine apm _ = apm -- e.g. hidden = yes

maybeM :: Monad m => (a -> m b) -> Maybe a -> m (Maybe b)
maybeM f = maybe (return Nothing) (fmap Just . f)

addModifier :: (EU4Info g, Monad m) =>
    ScriptMessage -> StatementHandler g m
addModifier kind stmt@(Statement _ OpEq (CompoundRhs scr)) =
    let amod = foldl' addModifierLine newAddModifier scr
    in if isJust (amod_name amod) || isJust (amod_key amod) then do
        let mkey = amod_key amod
            mname = amod_name amod
        mthemod <- join <$> sequence (getModifier <$> mname) -- Nothing if trade modifier
        tkind <- messageText kind
        mwho <- maybe (return Nothing)
                      (fmap (Just . Doc.doc2text) . flag (Just EU4Country))
                      (amod_who amod)
        mname_loc <- maybeM getGameL10n mname
        mkey_loc <- maybeM getGameL10n mkey
        let mdur = amod_duration amod
            mname_or_key = maybe mkey Just mname
            mname_or_key_loc = maybe mkey_loc Just mname_loc
            meffect = modEffects <$> mthemod
        mpp_meffect <- scope EU4Bonus $ maybeM ppMany meffect

        -- Is this a religious modifer?
        mpp_meffect' <- case (mpp_meffect, modReligious <$> mthemod) of
            (Just pp_meffect, Just True) -> do
                relMsg <- withCurrentIndent $ \i -> return (i + 1, MsgReligiousModifier)
                return $ Just $ pp_meffect ++ [relMsg]
            _ -> do return mpp_meffect

        case mname_or_key of
            Just modid ->
                -- default presented name to mod id
                let name_loc = fromMaybe modid mname_or_key_loc
                in case (mwho, amod_power amod, mdur, mpp_meffect') of
                    -- Event modifiers - expect effects
                    (Nothing,  Nothing,  Nothing, Just pp_effect)  -> do
                        msghead <- alsoIndent' (MsgGainMod modid tkind name_loc)
                        return (msghead : pp_effect)
                    (Nothing,  Nothing,  Just dur, Just pp_effect) -> do
                        msghead <- alsoIndent' (MsgGainModDur modid tkind name_loc dur)
                        return (msghead : pp_effect)
                    (Just who, Nothing,  Nothing, Just pp_effect)  -> do
                        msghead <- alsoIndent' (MsgActorGainsMod modid who tkind name_loc)
                        return (msghead : pp_effect)
                    (Just who, Nothing,  Just dur, Just pp_effect) -> do
                        msghead <- alsoIndent' (MsgActorGainsModDur modid who tkind name_loc dur)
                        return (msghead : pp_effect)
                    -- Trade power modifiers - expect no effects
                    (Nothing,  Just pow, Nothing, _)  -> msgToPP $ MsgGainModPow modid tkind name_loc pow
                    (Nothing,  Just pow, Just dur, _) -> msgToPP $ MsgGainModPowDur modid tkind name_loc pow dur
                    (Just who, Just pow, Nothing, _)  -> msgToPP $ MsgActorGainsModPow modid who tkind name_loc pow
                    (Just who, Just pow, Just dur, _) -> msgToPP $ MsgActorGainsModPowDur modid who tkind name_loc pow dur
                    _ -> do
                        traceM $ "strange modifier spec" ++ case (mkey, mname) of
                            (Just key, _) -> ": " ++ T.unpack key
                            (_, Just name) -> ": " ++ T.unpack name
                            _ -> ""
                        preStatement stmt
            _ -> preStatement stmt -- Must have mod id
    else preStatement stmt
addModifier _ stmt = preStatement stmt

-- Add core

-- "add_core = <n>" in country scope means "Gain core on <localize PROVn>"
-- "add_core = <tag>" in province scope means "<localize tag> gains core"
addCore :: (EU4Info g, Monad m) =>
    StatementHandler g m
addCore [pdx| %_ = $tag |]
  = msgToPP =<< do -- tag
    tagflag <- flagText (Just EU4Country) tag
    return $ MsgTagGainsCore tagflag
addCore [pdx| %_ = !num |]
  = msgToPP =<< do -- province
    prov <- getProvLoc num
    return $ MsgGainCoreOnProvince prov
addCore stmt = preStatement stmt

-- Opinions

-- Add an opinion modifier towards someone (for a number of years).
data AddOpinion = AddOpinion {
        op_who :: Maybe (Either Text (Text, Text))
    ,   op_modifier :: Maybe Text
    ,   op_years :: Maybe Double
    } deriving Show
newAddOpinion :: AddOpinion
newAddOpinion = AddOpinion Nothing Nothing Nothing

opinion :: (EU4Info g, Monad m) =>
    (Text -> Text -> Text -> ScriptMessage)
        -> (Text -> Text -> Text -> Double -> ScriptMessage)
        -> StatementHandler g m
opinion msgIndef msgDur stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_add_opinion (foldl' addLine newAddOpinion scr)
    where
        addLine :: AddOpinion -> GenericStatement -> AddOpinion
        addLine op [pdx| who           = $tag         |] = op { op_who = Just (Left tag) }
        addLine op [pdx| who           = $vartag:$var |] = op { op_who = Just (Right (vartag, var)) }
        addLine op [pdx| modifier      = ?label       |] = op { op_modifier = Just label }
        addLine op [pdx| years         = !n           |] = op { op_years = Just n }
        -- following two for add_mutual_opinion_modifier_effect
        addLine op [pdx| scope_country = $tag         |] = op { op_who = Just (Left tag) }
        addLine op [pdx| scope_country = $vartag:$var |] = op { op_who = Just (Right (vartag, var)) }
        addLine op [pdx| opinion_modifier = ?label    |] = op { op_modifier = Just label }
        addLine op _ = op
        pp_add_opinion op = case (op_who op, op_modifier op) of
            (Just ewhom, Just modifier) -> do
                mwhomflag <- eflag (Just EU4Country) ewhom
                mod_loc <- getGameL10n modifier
                case (mwhomflag, op_years op) of
                    (Just whomflag, Nothing) -> return $ msgIndef modifier mod_loc whomflag
                    (Just whomflag, Just years) -> return $ msgDur modifier mod_loc whomflag years
                    _ -> return (preMessage stmt)
            _ -> trace ("opinion: who or modifier missing: " ++ show stmt) $ return (preMessage stmt)
opinion _ _ stmt = preStatement stmt

data HasOpinion = HasOpinion
        {   hop_who :: Maybe Text
        ,   hop_value :: Maybe Double
        }
newHasOpinion :: HasOpinion
newHasOpinion = HasOpinion Nothing Nothing
hasOpinion :: forall g m. (EU4Info g, Monad m) =>
    (Double -> Text -> ScriptMessage) ->
    StatementHandler g m
hasOpinion msg stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_hasOpinion (foldl' addLine newHasOpinion scr)
    where
        addLine :: HasOpinion -> GenericStatement -> HasOpinion
        addLine hop [pdx| who   = ?who |] = hop { hop_who = Just who }
        addLine hop [pdx| value = !val |] = hop { hop_value = Just val }
        addLine hop _ = trace "warning: unrecognized has_opinion clause" hop
        pp_hasOpinion :: HasOpinion -> PPT g m ScriptMessage
        pp_hasOpinion hop = case (hop_who hop, hop_value hop) of
            (Just who, Just value) -> do
                who_flag <- flag (Just EU4Country) who
                return (msg value (Doc.doc2text who_flag))
            _ -> return (preMessage stmt)
hasOpinion _ stmt = preStatement stmt

-- Rebels

-- Render a rebel type atom (e.g. anti_tax_rebels) as their name and icon key.
-- This is needed because all religious rebels localize as simply "Religious" -
-- we want to be more specific.
rebel_loc :: HashMap Text (Text,Text)
rebel_loc = HM.fromList
        [("polish_noble_rebels",    ("Magnates", "magnates"))
        ,("lollard_rebels",         ("Lollard heretics", "lollards"))
        ,("catholic_rebels",        ("Catholic zealots", "catholic zealots"))
        ,("protestant_rebels",      ("Protestant zealots", "protestant zealots"))
        ,("reformed_rebels",        ("Reformed zealots", "reformed zealots"))
        ,("orthodox_rebels",        ("Orthodox zealots", "orthodox zealots"))
        ,("sunni_rebels",           ("Sunni zealots", "sunni zealots"))
        ,("shiite_rebels",          ("Shiite zealots", "shiite zealots"))
        ,("buddhism_rebels",        ("Buddhist zealots", "buddhist zealots"))
        ,("mahayana_rebels",        ("Mahayana zealots", "mahayana zealots"))
        ,("vajrayana_rebels",       ("Vajrayana zealots", "vajrayana zealots"))
        ,("hinduism_rebels",        ("Hindu zealots", "hindu zealots"))
        ,("confucianism_rebels",    ("Confucian zealots", "confucian zealots"))
        ,("shinto_rebels",          ("Shinto zealots", "shinto zealots"))
        ,("animism_rebels",         ("Animist zealots", "animist zealots"))
        ,("shamanism_rebels",       ("Fetishist zealots", "fetishist zealots"))
        ,("totemism_rebels",        ("Totemist zealots", "totemist zealots"))
        ,("coptic_rebels",          ("Coptic zealots", "coptic zealots"))
        ,("ibadi_rebels",           ("Ibadi zealots", "ibadi zealots"))
        ,("sikhism_rebels",         ("Sikh zealots", "sikh zealots"))
        ,("jewish_rebels",          ("Jewish zealots", "jewish zealots"))
        ,("norse_pagan_reformed_rebels", ("Norse zealots", "norse zealots"))
        ,("inti_rebels",            ("Inti zealots", "inti zealots"))
        ,("maya_rebels",            ("Maya zealots", "maya zealots"))
        ,("nahuatl_rebels",         ("Nahuatl zealots", "nahuatl zealots"))
        ,("tengri_pagan_reformed_rebels", ("Tengri zealots", "tengri zealots"))
        ,("zoroastrian_rebels",     ("Zoroastrian zealots", "zoroastrian zealots"))
        ,("ikko_ikki_rebels",       ("Ikko-Ikkis", "ikko-ikkis"))
        ,("ronin_rebels",           ("Ronin rebels", "ronin"))
        ,("reactionary_rebels",     ("Reactionaries", "reactionaries"))
        ,("anti_tax_rebels",        ("Peasants", "peasants"))
        ,("revolutionary_rebels",   ("Revolutionaries", "revolutionaries"))
        ,("heretic_rebels",         ("Heretics", "heretics"))
        ,("religious_rebels",       ("Religious zealots", "religious zealots"))
        ,("nationalist_rebels",     ("Separatist rebels", "separatists"))
        ,("noble_rebels",           ("Noble rebels", "noble rebels"))
        ,("colonial_rebels",        ("Colonial rebels", "colonial rebels")) -- ??
        ,("patriot_rebels",         ("Patriot rebels", "patriot"))
        ,("pretender_rebels",       ("Pretender rebels", "pretender"))
        ,("colonial_patriot_rebels", ("Colonial patriot", "colonial patriot")) -- ??
        ,("particularist_rebels",   ("Particularist rebels", "particularist"))
        ,("nationalist_rebels",     ("Separatist rebels", "separatists"))
        ]

-- Spawn a rebel stack.
data SpawnRebels = SpawnRebels {
        rebelType :: Maybe Text
    ,   rebelSize :: Maybe Double
    ,   friend :: Maybe Text
    ,   win :: Bool
    ,   sr_unrest :: Maybe Double -- rebel faction progress
    ,   sr_leader :: Maybe Text
    } deriving Show
newSpawnRebels :: SpawnRebels
newSpawnRebels = SpawnRebels Nothing Nothing Nothing False Nothing Nothing

spawnRebels :: forall g m. (EU4Info g, Monad m) =>
    Maybe Text -> StatementHandler g m
spawnRebels mtype stmt = msgToPP =<< spawnRebels' mtype stmt where
    spawnRebels' Nothing [pdx| %_ = @scr |]
        = pp_spawnRebels $ foldl' addLine newSpawnRebels scr
    spawnRebels' rtype [pdx| %_ = !size |]
        = pp_spawnRebels $ newSpawnRebels { rebelType = rtype, rebelSize = Just size }
    spawnRebels' _ stmt' = (trace $ "Not handled in spawnRebels: " ++ show stmt) $ return (preMessage stmt')

    addLine :: SpawnRebels -> GenericStatement -> SpawnRebels
    addLine op [pdx| type   = $tag  |] = op { rebelType = Just tag }
    addLine op [pdx| size   = !n    |] = op { rebelSize = Just n }
    addLine op [pdx| friend = $tag  |] = op { friend = Just tag }
    addLine op [pdx| win    = yes   |] = op { win = True }
    addLine op [pdx| unrest = !n    |] = op { sr_unrest = Just n }
    addLine op [pdx| leader = ?name |] = op { sr_leader = Just name }
    addLine op _ = op

    pp_spawnRebels :: SpawnRebels -> PPT g m ScriptMessage
    pp_spawnRebels reb
        = case rebelSize reb of
            Just size -> do
                let rtype_loc_icon = flip HM.lookup rebel_loc =<< rebelType reb
                friendText <- case friend reb of
                    Just thefriend -> do
                        cflag <- flagText (Just EU4Country) thefriend
                        mtext <- messageText (MsgRebelsFriendlyTo cflag)
                        return (" (" <> mtext <> ")")
                    Nothing -> return ""
                leaderText <- case sr_leader reb of
                    Just leader -> do
                        mtext <- messageText (MsgRebelsLedBy leader)
                        return (" (" <> mtext <> ")")
                    Nothing -> return ""
                progressText <- case sr_unrest reb of
                    Just unrest -> do
                        mtext <- messageText (MsgRebelsGainProgress unrest)
                        return (" (" <> mtext <> ")")
                    Nothing -> return ""
                return $ MsgSpawnRebels
                            (maybe "" (\(ty, ty_icon) -> iconText ty_icon <> " " <> ty) rtype_loc_icon)
                            size
                            friendText
                            leaderText
                            (win reb)
                            progressText
            _ -> return $ preMessage stmt

spawnRebelsSimple :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
spawnRebelsSimple stmt@[pdx| $typ = %_ |] = spawnRebels (Just typ) stmt
spawnRebelsSimple stmt = spawnRebels Nothing stmt -- Will probably fail

hasSpawnedRebels :: (EU4Info g, Monad m) => StatementHandler g m
hasSpawnedRebels [pdx| %_ = $rtype |]
    | Just (rtype_loc, rtype_iconkey) <- HM.lookup rtype rebel_loc
      = msgToPP $ MsgRebelsHaveRisen (iconText rtype_iconkey) rtype_loc
hasSpawnedRebels stmt = preStatement stmt

canSpawnRebels :: (EU4Info g, Monad m) => StatementHandler g m
canSpawnRebels [pdx| %_ = $rtype |]
    | Just (rtype_loc, rtype_iconkey) <- HM.lookup rtype rebel_loc
      = msgToPP (MsgProvinceHasRebels (iconText rtype_iconkey) rtype_loc)
canSpawnRebels stmt = preStatement stmt

-- Events

data TriggerEvent = TriggerEvent
        { e_id :: Maybe Text
        , e_title_loc :: Maybe Text
        , e_days :: Maybe Double
        }
newTriggerEvent :: TriggerEvent
newTriggerEvent = TriggerEvent Nothing Nothing Nothing
triggerEvent :: forall g m. (EU4Info g, Monad m) => ScriptMessage -> StatementHandler g m
triggerEvent evtType stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_trigger_event =<< foldM addLine newTriggerEvent scr
    where
        addLine :: TriggerEvent -> GenericStatement -> PPT g m TriggerEvent
        addLine evt [pdx| id = ?!eeid |]
            | Just eid <- either (\n -> T.pack (show (n::Int))) id <$> eeid
            = do
                mevt_t <- getEventTitle eid
                return evt { e_id = Just eid, e_title_loc = mevt_t }
        addLine evt [pdx| days = %rhs |]
            = return evt { e_days = floatRhs rhs }
        addLine evt _ = return evt
        pp_trigger_event :: TriggerEvent -> PPT g m ScriptMessage
        pp_trigger_event evt = do
            evtType_t <- messageText evtType
            case e_id evt of
                Just msgid ->
                    let loc = fromMaybe msgid (e_title_loc evt)
                    in case e_days evt of
                        Just days -> return $ MsgTriggerEventDays evtType_t msgid loc days
                        Nothing -> return $ MsgTriggerEvent evtType_t msgid loc
                _ -> return $ preMessage stmt
triggerEvent _ stmt = preStatement stmt

-- Specific values

gainMen :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
gainMen [pdx| $head = !amt |]
    | "add_manpower" <- head = gainMen' ("manpower"::Text) MsgGainMPFrac MsgGainMP 1000
    | "add_sailors" <- head = gainMen' ("sailors"::Text) MsgGainSailorsFrac MsgGainSailors 1
    where
        gainMen' theicon msgFrac msgWhole mult = msgToPP =<<
            if abs (amt::Double) < 1
            --  interpret amt as a fraction of max
            then return $ msgFrac (iconText theicon) amt
            --  interpret amt as exact number, multiplied by mult
            else return $ msgWhole (iconText theicon) (amt*mult)
gainMen stmt = preStatement stmt

-- Casus belli

data AddCB = AddCB
    {   acb_target_flag :: Maybe Text
    ,   acb_type :: Maybe Text
    ,   acb_type_loc :: Maybe Text
    ,   acb_months :: Maybe Double
    }
newAddCB :: AddCB
newAddCB = AddCB Nothing Nothing Nothing Nothing
addCB :: forall g m. (EU4Info g, Monad m) =>
    Bool -- ^ True for add_casus_belli, False for reverse_add_casus_belli
        -> StatementHandler g m
addCB direct stmt@[pdx| %_ = @scr |]
    = msgToPP . pp_add_cb =<< foldM addLine newAddCB scr where
        addLine :: AddCB -> GenericStatement -> PPT g m AddCB
        addLine acb [pdx| target = $target |]
            = (\target_loc -> acb
                  { acb_target_flag = target_loc })
              <$> eflag (Just EU4Country) (Left target)
        addLine acb [pdx| target = $vartag:$var |]
            = (\target_loc -> acb
                  { acb_target_flag = target_loc })
              <$> eflag (Just EU4Country) (Right (vartag, var))
        addLine acb [pdx| type = $cbtype |]
            = (\cbtype_loc -> acb
                  { acb_type = Just cbtype
                  , acb_type_loc = cbtype_loc })
              <$> getGameL10nIfPresent cbtype
        addLine acb [pdx| months = %rhs |]
            = return $ acb { acb_months = floatRhs rhs }
        addLine acb _ = return acb
        pp_add_cb :: AddCB -> ScriptMessage
        pp_add_cb acb =
            let msg = if direct then MsgGainCB else MsgReverseGainCB
                msg_dur = if direct then MsgGainCBDuration else MsgReverseGainCBDuration
            in case (acb_type acb, acb_type_loc acb,
                     acb_target_flag acb,
                     acb_months acb) of
                (Nothing, _, _, _) -> preMessage stmt -- need CB type
                (_, _, Nothing, _) -> preMessage stmt -- need target
                (_, Just cbtype_loc, Just target_flag, Just months) -> msg_dur cbtype_loc target_flag months
                (Just cbtype, Nothing, Just target_flag, Just months) -> msg_dur cbtype target_flag months
                (_, Just cbtype_loc, Just target_flag, Nothing) -> msg cbtype_loc target_flag
                (Just cbtype, Nothing, Just target_flag, Nothing) -> msg cbtype target_flag
addCB _ stmt = preStatement stmt

-- Random

random :: (EU4Info g, Monad m) => StatementHandler g m
random stmt@[pdx| %_ = @scr |]
    | (front, back) <- break
                        (\substmt -> case substmt of
                            [pdx| chance = %_ |] -> True
                            _ -> False)
                        scr
      , not (null back)
      , [pdx| %_ = %rhs |] <- head back
      , Just chance <- floatRhs rhs
      = compoundMessage
          (MsgRandomChance chance)
          [pdx| %undefined = @(front ++ tail back) |]
    | otherwise = compoundMessage MsgRandom stmt
random stmt = preStatement stmt


toPct :: Double -> Double
toPct num = (fromIntegral $ round (num * 1000)) / 10 -- round to one digit after the point

randomList :: (EU4Info g, Monad m) => StatementHandler g m
randomList stmt@[pdx| %_ = @scr |] = fmtRandomList $ map entry scr
    where
        entry [pdx| !weight = @scr |] = (fromIntegral weight, scr)
        entry _ = error "Bad clause in random_list"
        fmtRandomList entries = withCurrentIndent $ \i ->
            let total = sum (map fst entries)
            in (:) <$> pure (i, MsgRandom)
                   <*> (concat <$> indentUp (mapM (fmtRandomList' total) entries))
        fmtRandomList' total (wt, what) = do
            -- TODO: Could probably be simplified.
            let (mtrigger, rest) = extractStmt (matchLhsText "trigger") what
                (mmodifier, rest') = extractStmt (matchLhsText "modifier") rest
            trig <- (case mtrigger of
                Just s -> indentUp (compoundMessage MsgRandomListTrigger s)
                _ -> return [])
            mod <- indentUp (case mmodifier of
                Just s@[pdx| %_ = @scr |] ->
                    let
                        (mfactor, s') = extractStmt (matchLhsText "factor") scr
                    in
                        case mfactor of
                            Just [pdx| %_ = !factor |] -> do
                                cond <- ppMany s'
                                liftA2 (++) (msgToPP $ MsgRandomListModifier factor) (pure cond)
                            _ -> preStatement s
                Just s -> preStatement s
                _ -> return [])
            body <- ppMany rest' -- has integral indentUp
            liftA2 (++)
                (msgToPP $ MsgRandomChance $ toPct (wt / total))
                (pure (trig ++ mod ++ body))
randomList _ = withCurrentFile $ \file ->
    error ("randomList sent strange statement in " ++ file)

-- Advisors

data DefineAdvisor = DefineAdvisor
    {   da_type :: Maybe Text
    ,   da_type_loc :: Maybe Text
    ,   da_name :: Maybe Text
    ,   da_discount :: Maybe Double
    ,   da_location :: Maybe Int
    ,   da_location_loc :: Maybe Text
    ,   da_skill :: Maybe Double
    ,   da_female :: Maybe Bool
    }
newDefineAdvisor :: DefineAdvisor
newDefineAdvisor = DefineAdvisor Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing

defineAdvisor :: forall g m. (EU4Info g, Monad m) => Bool -> StatementHandler g m
defineAdvisor isScaled stmt@[pdx| %_ = @scr |]
    = msgToPP . pp_define_advisor =<< foldM addLine newDefineAdvisor scr where
        addLine :: DefineAdvisor -> GenericStatement -> PPT g m DefineAdvisor
        addLine da [pdx| $lhs = %rhs |] = case T.map toLower lhs of
            "type" ->
                let mthe_type = case rhs of
                        GenericRhs a_type [] -> Just a_type
                        StringRhs a_type -> Just a_type
                        _ -> Nothing
                in (\mtype_loc -> da
                        { da_type = mthe_type
                        , da_type_loc = mtype_loc })
                   <$> maybe (return Nothing) getGameL10nIfPresent mthe_type
            "name" -> return $
                let mthe_name = case rhs of
                        GenericRhs a_name [] -> Just a_name
                        StringRhs a_name -> Just a_name
                        _ -> Nothing
                in da { da_name = mthe_name }
            "discount" -> return $
                let yn = case rhs of
                        GenericRhs yn' [] -> Just yn'
                        StringRhs yn' -> Just yn'
                        _ -> Nothing
                in if yn == Just "yes" then da { da_discount = Just 0.5 }
                   else if yn == Just "no" then da { da_discount = Just 0.0 }
                   else da
            "cost_multiplier" -> return $ da { da_discount = floatRhs rhs }
            "location" -> do
                let location_code = floatRhs rhs
                location_loc <- sequence (getProvLoc <$> location_code)
                return $ da { da_location = location_code
                            , da_location_loc = location_loc }
            "skill" -> return $ da { da_skill = floatRhs rhs }
            "female" -> return $
                let yn = case rhs of
                        GenericRhs yn' [] -> Just yn'
                        StringRhs yn' -> Just yn'
                        _ -> Nothing
                in if yn == Just "yes" then da { da_female = Just True }
                   else if yn == Just "no" then da { da_female = Just False }
                   else da
            "culture" -> return da -- TODO: Ignored for now
            "religion" -> return da -- TODO: Ignored for now
            param -> trace ("warning: unknown define_advisor parameter: " ++ show param) $ return da
        addLine da _ = return da
        pp_define_advisor :: DefineAdvisor -> ScriptMessage
        pp_define_advisor da =
            case da_skill da of
                Just skill ->
                    let mdiscount = da_discount da
                        discount = fromMaybe 0.0 mdiscount
                        mlocation_loc = da_location_loc da
                        mlocation = mlocation_loc `mplus` (T.pack . show <$> da_location da)
                    in case (da_female da,
                               da_type_loc da,
                               da_name da,
                               mlocation) of
                        (Nothing, Nothing, Nothing, Nothing)
                            -> MsgGainAdvisor skill discount
                        (Nothing, Nothing, Nothing, Just location)
                            ->MsgGainAdvisorLoc location skill discount
                        (Nothing, Nothing, Just name, Nothing)
                            -> MsgGainAdvisorName name skill discount
                        (Nothing, Nothing, Just name, Just location)
                            -> MsgGainAdvisorNameLoc name location skill discount
                        (Nothing, Just advtype, Nothing, Nothing)
                            -> MsgGainAdvisorType advtype skill discount
                        (Nothing, Just advtype, Nothing, Just location)
                            -> MsgGainAdvisorTypeLoc advtype location skill discount
                        (Nothing, Just advtype, Just name, Nothing)
                            -> MsgGainAdvisorTypeName advtype name skill discount
                        (Nothing, Just advtype, Just name, Just location)
                            -> MsgGainAdvisorTypeNameLoc advtype name location skill discount
                        (Just female, Nothing, Nothing, Nothing)
                            -> MsgGainFemaleAdvisor female skill discount
                        (Just female, Nothing, Nothing, Just location)
                            -> MsgGainFemaleAdvisorLoc female location skill discount
                        (Just female, Nothing, Just name, Nothing)
                            -> MsgGainFemaleAdvisorName female name skill discount
                        (Just female, Nothing, Just name, Just location)
                            -> MsgGainFemaleAdvisorNameLoc female name location skill discount
                        (Just female, Just advtype, Nothing, Nothing)
                            -> MsgGainFemaleAdvisorType female advtype skill discount
                        (Just female, Just advtype, Nothing, Just location)
                            -> MsgGainFemaleAdvisorTypeLoc female advtype location skill discount
                        (Just female, Just advtype, Just name, Nothing)
                            -> MsgGainFemaleAdvisorTypeName female advtype name skill discount
                        (Just female, Just advtype, Just name, Just location)
                            -> MsgGainFemaleAdvisorTypeNameLoc female advtype name location skill discount
                _ -> case (isScaled, da_type_loc da) of
                        (True, Just advType) -> MsgGainScaledAdvisor advType (fromMaybe 0.0 (da_discount da))
                        _ -> preMessage stmt
defineAdvisor _ stmt = preStatement stmt

-------------
-- Dynasty --
-------------

data Dynasty
    = DynText Text
    | DynPron Text
    | DynOriginal
    | DynHistoric

data DefineDynMember = DefineDynMember
    {   ddm_rebel :: Bool
    ,   ddm_name :: Maybe Text
    ,   ddm_dynasty :: Maybe Dynasty
    ,   ddm_age :: Maybe Double
    ,   ddm_female :: Maybe Bool
    ,   ddm_claim :: Maybe Double
    ,   ddm_regency :: Bool
    ,   ddm_adm :: Maybe Int
    ,   ddm_dip :: Maybe Int
    ,   ddm_mil :: Maybe Int
    ,   ddm_fixed :: Bool
    ,   ddm_any_rand :: Bool
    ,   ddm_max_adm :: Maybe Int
    ,   ddm_max_dip :: Maybe Int
    ,   ddm_max_mil :: Maybe Int
    ,   ddm_culture :: Maybe (Either Text Text)
    ,   ddm_religion :: Maybe (Either Text Text)
    ,   ddm_attach_leader :: Maybe Text
    ,   ddm_hidden_skills :: Bool
    ,   ddm_min_age :: Maybe Int
    ,   ddm_max_age :: Maybe Int
    ,   ddm_random_gender :: Maybe Bool
    ,   ddm_block_disinherit :: Bool
    ,   ddm_birth_date :: Maybe Text
    ,   ddm_bastard :: Bool
    ,   ddm_country :: Maybe Text
    ,   ddm_exiled_as :: Maybe Text
    ,   ddm_force_republican_names :: Bool
    }
newDefineDynMember :: DefineDynMember
newDefineDynMember = DefineDynMember False Nothing Nothing Nothing Nothing Nothing False Nothing Nothing Nothing False False Nothing Nothing Nothing Nothing Nothing Nothing False Nothing Nothing Nothing False Nothing False Nothing Nothing False

defineDynMember :: forall g m. (EU4Info g, Monad m) =>
    (Bool -> ScriptMessage) ->
    (Bool -> Text -> ScriptMessage) ->
    (Bool -> ScriptMessage) ->
    (Bool -> Text -> ScriptMessage) ->
    StatementHandler g m
defineDynMember msgNew msgNewLeader msgNewAttribs msgNewLeaderAttribs [pdx| %_ = @scr |] = do
    -- Since addLine is pure, we have to prepare these in advance in case we
    -- need them.
    currentFile <- withCurrentFile $ \f -> return f
    prevPronoun <- Doc.doc2text <$> pronoun Nothing "PREV"
    rootPronoun <- Doc.doc2text <$> pronoun Nothing "ROOT"
    thisPronoun <- Doc.doc2text <$> pronoun Nothing "THIS"
    fromPronoun <- Doc.doc2text <$> pronoun Nothing "FROM"
    hrePronoun  <- Doc.doc2text <$> pronoun Nothing "emperor" -- needs l10n
    let testPronoun :: Maybe Text -> Maybe (Either Text Text)
        testPronoun (Just "PREV") = Just (Right prevPronoun)
        testPronoun (Just "ROOT") = Just (Right rootPronoun)
        testPronoun (Just "THIS") = Just (Right thisPronoun)
        testPronoun (Just "FROM") = Just (Right fromPronoun)
        testPronoun (Just "emperor") = Just (Right hrePronoun)
        testPronoun (Just other) | isJust (T.find (== ':') other) = Just (Right ("<tt>" <> other <> "</tt>")) -- event target (a bit of a hack)
        testPronoun (Just other) = Just (Left other)
        testPronoun _ = Nothing

        -- For now it seems we can get away with this, but be on the lookout
        checkRandomStats :: DefineDynMember -> DefineDynMember
        checkRandomStats ddm = case (ddm_fixed ddm, ddm_any_rand ddm) of
            (True, True) -> trace ("warning: defineDynMember: mixed use of random and fixed stats in " ++ currentFile ++ ": " ++ show scr) $ ddm
            _ -> ddm

        -- native_americans.6 in 1.33.2 has "change_adm = 0", omit such lines but retain ddm_any_rand logic
        ignoreNoChange :: GenericRhs -> Maybe Int
        ignoreNoChange rhs = case floatRhs rhs of
            Just 0 -> Nothing
            x -> x

        addLine :: DefineDynMember -> GenericStatement -> DefineDynMember
        addLine ddm stmt@[pdx| $lhs = %rhs |] = case T.map toLower lhs of
            "rebel" -> case textRhs rhs of
                Just "yes" -> ddm { ddm_rebel = True }
                _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm
            "name" -> ddm { ddm_name = textRhs rhs }
            "dynasty" -> ddm { ddm_dynasty = case testPronoun $ textRhs rhs of
                Just (Right pronoun) -> Just (DynPron pronoun)
                Just (Left "original_dynasty") -> Just DynOriginal
                Just (Left "historic_dynasty") -> Just DynHistoric
                Just (Left other) -> Just (DynText other)
                _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ Nothing }
            "age" -> ddm { ddm_age = floatRhs rhs }
            "male" -> case textRhs rhs of
                Just "yes" -> ddm { ddm_female = Just False }
                Just "no"  -> ddm { ddm_female = Just True }
                _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm
            "female" -> case textRhs rhs of
                Just "yes" -> ddm { ddm_female = Just True }
                Just "no"  -> ddm { ddm_female = Just False }
                _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm
            "claim" -> ddm { ddm_claim = floatRhs rhs }
            "regency" -> case textRhs rhs of
                Just "yes" -> ddm { ddm_regency = True }
                Just "no" -> ddm { ddm_regency = False }
                _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm
            "adm" -> ddm { ddm_adm = floatRhs rhs, ddm_fixed = True }
            "dip" -> ddm { ddm_dip = floatRhs rhs, ddm_fixed = True }
            "mil" -> ddm { ddm_mil = floatRhs rhs, ddm_fixed = True }
            "change_adm" -> ddm { ddm_adm = ignoreNoChange rhs, ddm_any_rand = True }
            "change_dip" -> ddm { ddm_dip = ignoreNoChange rhs, ddm_any_rand = True }
            "change_mil" -> ddm { ddm_mil = ignoreNoChange rhs, ddm_any_rand = True }
            "max_random_adm" -> ddm { ddm_max_adm = floatRhs rhs, ddm_any_rand = True }
            "max_random_dip" -> ddm { ddm_max_dip = floatRhs rhs, ddm_any_rand = True }
            "max_random_mil" -> ddm { ddm_max_mil = floatRhs rhs, ddm_any_rand = True }
            -- Fixed is the default in 1.32
            "fixed" -> case textRhs rhs of
                Just "yes" -> trace ("warning: defineDynMember: use of obsolote parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm { ddm_fixed = True }
                _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm
            "force_republican_names" -> case textRhs rhs of
                Just "yes" -> ddm { ddm_force_republican_names = True }
                _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm
            "culture" -> ddm { ddm_culture = testPronoun $ textRhs rhs }
            "religion" -> ddm { ddm_religion = testPronoun $ textRhs rhs }
            "attach_leader" -> ddm { ddm_attach_leader = textRhs rhs }
            x | x `elem` ["hide_skills", "hidden"] -> case textRhs rhs of
                Just "yes" -> ddm { ddm_hidden_skills = True }
                _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm
            "min_age" -> ddm { ddm_min_age = floatRhs rhs }
            "max_age" -> ddm { ddm_max_age = floatRhs rhs }
            "random_gender" -> case textRhs rhs of
                Just "yes" -> ddm { ddm_random_gender = Just True }
                _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm
            "block_disinherit" -> case textRhs rhs of
                Just "yes" -> ddm { ddm_block_disinherit = True }
                _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm
            "birth_date" -> ddm { ddm_birth_date = textRhs rhs }
            "no_consort_with_heir" -> case textRhs rhs of
                Just "yes" -> ddm { ddm_bastard = True }
                _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm
            "country_of_origin" -> ddm { ddm_country = textRhs rhs }
            "exiled_as" -> ddm { ddm_exiled_as = textRhs rhs }
            "option" -> ddm -- Ignore for now (used for exiled rulers in elections)
            _ -> trace ("warning: unknown defineDynMember parameter in " ++ currentFile ++ ": " ++ show stmt) $ ddm
        addLine ddm _ = ddm

        pp_define_dyn_member :: DefineDynMember -> PPT g m IndentedMessages
        pp_define_dyn_member    DefineDynMember { ddm_rebel = True } = msgToPP MsgRebelLeaderRuler
        pp_define_dyn_member ddm@DefineDynMember { ddm_regency = regency, ddm_attach_leader = mleader } = do
            body <- indentUp (unfoldM pp_define_dyn_member_attrib ddm)
            if null body then
                msgToPP (maybe (msgNew regency) (msgNewLeader regency) mleader)
            else
                liftA2 (++)
                    (msgToPP (maybe (msgNewAttribs regency) (msgNewLeaderAttribs regency) mleader))
                    (pure body)
        pp_define_dyn_member_attrib :: DefineDynMember -> PPT g m (Maybe (IndentedMessage, DefineDynMember))
        -- "Named <foo>"
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_name = Just name } = do
            [msg] <- msgToPP (MsgNamed name)
            return (Just (msg, ddm { ddm_name = Nothing }))
        -- "Of the <foo> dynasty"
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_dynasty = Just dynasty } =
            case dynasty of
                DynText dyntext -> do
                    [msg] <- msgToPP (MsgNewDynMemberDynasty dyntext)
                    return (Just (msg, ddm { ddm_dynasty = Nothing }))
                DynPron dyntext -> do
                    [msg] <- msgToPP (MsgNewDynMemberDynastyAs dyntext)
                    return (Just (msg, ddm { ddm_dynasty = Nothing }))
                DynOriginal -> do
                    [msg] <- msgToPP MsgNewDynMemberOriginalDynasty
                    return (Just (msg, ddm { ddm_dynasty = Nothing }))
                DynHistoric -> do
                    [msg] <- msgToPP MsgNewDynMemberHistoricDynasty
                    return (Just (msg, ddm { ddm_dynasty = Nothing }))
        -- "Aged <foo> years"
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_age = Just age } = do
            [msg] <- msgToPP (MsgNewDynMemberAge age)
            return (Just (msg, ddm { ddm_age = Nothing }))
        -- "With {{icon|adm}} <foo> administrative skill"
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_adm = Just adm, ddm_fixed = fixed } = do
            [msg] <- msgToPP (MsgNewDynMemberAdm fixed (fromIntegral adm))
            return (Just (msg, ddm { ddm_adm = Nothing }))
        -- "With {{icon|adm}} <foo> diplomatic skill"
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_dip = Just dip, ddm_fixed = fixed } = do
            [msg] <- msgToPP (MsgNewDynMemberDip fixed (fromIntegral dip))
            return (Just (msg, ddm { ddm_dip = Nothing }))
        -- "With {{icon|adm}} <foo> military skill"
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_mil = Just mil, ddm_fixed = fixed } = do
            [msg] <- msgToPP (MsgNewDynMemberMil fixed (fromIntegral mil))
            return (Just (msg, ddm { ddm_mil = Nothing }))
        -- "At most <foo> skill"
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_max_adm = Just adm } = do
            [msg] <- msgToPP (MsgNewDynMemberMaxAdm (fromIntegral adm))
            return (Just (msg, ddm { ddm_max_adm = Nothing }))
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_max_dip = Just dip } = do
            [msg] <- msgToPP (MsgNewDynMemberMaxDip (fromIntegral dip))
            return (Just (msg, ddm { ddm_max_dip = Nothing }))
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_max_mil = Just mil } = do
            [msg] <- msgToPP (MsgNewDynMemberMaxMil (fromIntegral mil))
            return (Just (msg, ddm { ddm_max_mil = Nothing }))
        -- "Claim strength <foo>"
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_claim = Just claim } = do
            [msg] <- msgToPP $ MsgNewDynMemberClaim claim
            return (Just (msg, ddm { ddm_claim = Nothing }))
        -- "Of the <foo> culture"
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_culture = Just culture } = case culture of
            Left cultureText -> do
              locCulture <- getGameL10n cultureText
              [msg] <- msgToPP $ MsgNewDynMemberCulture locCulture
              return (Just (msg, ddm { ddm_culture = Nothing }))
            Right cultureText -> do
              [msg] <- msgToPP $ MsgNewDynMemberCultureAs cultureText
              return (Just (msg, ddm { ddm_culture = Nothing }))
        -- "Following the <foo> religion"
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_religion = Just religion } = case religion of
            Left religionText  -> do
              locReligion <- getGameL10n religionText
              [msg] <- msgToPP $ MsgNewDynMemberReligion (iconText religionText) locReligion
              return (Just (msg, ddm { ddm_religion = Nothing }))
            Right religionText -> do
              [msg] <- msgToPP $ MsgNewDynMemberReligionAs religionText
              return (Just (msg, ddm { ddm_religion = Nothing }))
        -- "With skills hidden"
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_hidden_skills = True } = do
            [msg] <- msgToPP $ MsgNewDynMemberHiddenSkills
            return (Just (msg, ddm { ddm_hidden_skills = False }))
        -- Random gender
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_random_gender = Just True } = do
            [msg] <- msgToPP $ MsgNewDynMemberRandomGender
            return (Just (msg, ddm { ddm_random_gender = Nothing }))
        -- Assigned gender
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_female = Just female } = do
            [msg] <- msgToPP $ MsgWithGender (not female)
            return (Just (msg, ddm { ddm_female = Nothing }))
        -- Min age
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_min_age = Just age } = do
            [msg] <- msgToPP (MsgNewDynMemberMinAge (fromIntegral age))
            return (Just (msg, ddm { ddm_min_age = Nothing }))
        -- Max age
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_max_age = Just age } = do
            [msg] <- msgToPP (MsgNewDynMemberMaxAge (fromIntegral age))
            return (Just (msg, ddm { ddm_max_age = Nothing }))
        -- Disinherit blockde
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_block_disinherit = True } = do
            [msg] <- msgToPP $ MsgNewDynMemberBlockDisinherit
            return (Just (msg, ddm { ddm_block_disinherit = False }))
        -- Birth date
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_birth_date = Just date } = do
            [msg] <- msgToPP $ MsgNewDynMemberBirthdate date
            return (Just (msg, ddm { ddm_birth_date = Nothing }))
        -- Bastard
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_bastard = True } = do
            [msg] <- msgToPP $ MsgNewDynMemberBastard
            return (Just (msg, ddm { ddm_bastard = False }))
        -- Country of origin
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_country = Just country } = do
            countryText <- flagText (Just EU4Country) country
            [msg] <- msgToPP $ MsgNewDynMemberCountry countryText
            return (Just (msg, ddm { ddm_country = Nothing }))
        -- Exile name
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_exiled_as = Just exiled_as } = do
            [msg] <- msgToPP (MsgExiledAs exiled_as)
            return (Just (msg, ddm { ddm_exiled_as = Nothing }))
        -- Force republican names
        pp_define_dyn_member_attrib ddm@DefineDynMember { ddm_force_republican_names = True } = do
            [msg] <- msgToPP $ MsgNewDynMemberForceRepublicanNames
            return (Just (msg, ddm { ddm_force_republican_names = False }))
        -- Nothing left
        pp_define_dyn_member_attrib _ = return Nothing
    pp_define_dyn_member $ checkRandomStats $ foldl' addLine newDefineDynMember scr
defineDynMember _ _ _ _ stmt = preStatement stmt

-- Rulers

defineRuler :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
-- Estate led regency (for now, handled here since there aren't other parameters supported)
defineRuler stmt@(Statement (GenericLhs _ []) OpEq (CompoundRhs [Statement (GenericLhs "regency" []) OpEq (CompoundRhs [Statement (GenericLhs "estate" []) OpEq (GenericRhs estate [])])])) = do
    estateLoc <- getGameL10n estate
    msgToPP $ MsgNewEstateRegency (iconText estate) estateLoc
defineRuler stmt = defineDynMember MsgNewRuler MsgNewRulerLeader MsgNewRulerAttribs MsgNewRulerLeaderAttribs stmt

defineExiledRuler :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
defineExiledRuler = defineDynMember (\_ -> MsgNewExiledRuler) (\_ -> \_ -> MsgNewExiledRuler) (\_ -> MsgNewExiledRulerAttribs) (\_ -> \_ -> MsgNewExiledRulerAttribs)

-- Heirs

defineHeir :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
defineHeir = defineDynMember (\_ -> MsgNewHeir) (\_ -> \_ -> MsgNewHeir) (\_ -> MsgNewHeirAttribs) (\_ -> \_ -> MsgNewHeirAttribs)

-- Consorts

defineConsort :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
defineConsort = defineDynMember (\_ -> MsgNewConsort) (\_ -> \_ -> MsgNewConsort) (\_ -> MsgNewConsortAttribs) (\_ -> \_ -> MsgNewConsortAttribs)

--------------------
-- Building units --
--------------------

data UnitType
    = UnitInfantry
    | UnitCavalry
    | UnitArtillery
    | UnitHeavyShip
    | UnitLightShip
    | UnitGalley
    | UnitTransport
    deriving (Show)

instance Param UnitType where
    toParam (textRhs -> Just "heavy_ship") = Just UnitHeavyShip
    toParam (textRhs -> Just "light_ship") = Just UnitLightShip
    toParam (textRhs -> Just "galley")     = Just UnitGalley
    toParam (textRhs -> Just "transport")  = Just UnitTransport
    toParam _ = Nothing

--buildToForcelimit :: (IsGameState (GameState g), Monad m) => StatementHandler g m
foldCompound "buildToForcelimit" "BuildToForcelimit" "btf"
    []
    [CompField "infantry" [t|Double|] (Just [|0|]) False
    ,CompField "cavalry" [t|Double|] (Just [|0|]) False
    ,CompField "artillery" [t|Double|] (Just [|0|]) False
    ,CompField "heavy_ship" [t|Double|] (Just [|0|]) False
    ,CompField "light_ship" [t|Double|] (Just [|0|]) False
    ,CompField "galley" [t|Double|] (Just [|0|]) False
    ,CompField "transport" [t|Double|] (Just [|0|]) False
    ]
    [| let has_infantry = _infantry > 0
           has_cavalry = _cavalry > 0
           has_artillery = _artillery > 0
           has_heavy_ship = _heavy_ship > 0
           has_light_ship = _light_ship > 0
           has_galley = _galley > 0
           has_transport = _transport > 0
           has_land = has_infantry || has_cavalry || has_artillery
           has_navy = has_heavy_ship || has_light_ship || has_galley || has_transport
           infIcon = iconText "infantry"
           cavIcon = iconText "cavalry"
           artIcon = iconText "artillery"
           heavyIcon = iconText "heavy ship"
           lightIcon = iconText "light ship"
           gallIcon = iconText "galley"
           transpIcon = iconText "transport"
       in return $ (if has_land == has_navy then do
                MsgBuildToForcelimit infIcon _infantry
                                     cavIcon _cavalry
                                     artIcon _artillery
                                     heavyIcon _heavy_ship
                                     lightIcon _light_ship
                                     gallIcon _galley
                                     transpIcon _transport
            else if has_land then
                MsgBuildToForcelimitLand infIcon _infantry
                                         cavIcon _cavalry
                                         artIcon _artillery
            else -- has_navy == True
                MsgBuildToForcelimitNavy heavyIcon _heavy_ship
                                         lightIcon _light_ship
                                         gallIcon _galley
                                         transpIcon _transport)
    |]

--addUnitConstruction :: (IsGameState (GameState g), Monad m) => Text -> StatementHandler g m
foldCompound "addUnitConstruction" "UnitConstruction" "uc"
    []
    [CompField "amount" [t|Double|] (Just [|1|]) False
    ,CompField "type" [t|UnitType|] Nothing True
    ,CompField "speed" [t|Double|] (Just [|1|]) False
    ,CompField "cost" [t|Double|] (Just [|1|]) False]
    [| return $ (case _type of
            UnitHeavyShip -> MsgBuildHeavyShips (iconText "heavy ship")
            UnitLightShip -> MsgBuildLightShips (iconText "light ship")
            UnitGalley    -> MsgBuildGalleys    (iconText "galley")
            UnitTransport -> MsgBuildTransports (iconText "transport")
       ) _amount _speed _cost
    |]

foldCompound "hasLeaders" "HasLeaders" "hl"
    []
    [CompField "value" [t|Double|] Nothing True
    ,CompField "type" [t|Text|] Nothing True
    ,CompField "include_monarch" [t|Text|] Nothing True
    ,CompField "include_heir" [t|Text|] Nothing True]
    [| do
        -- XXX: Should allow localization of description
        typeLoc <- getGameL10n _type
        return $ MsgHasLeaders (iconText _type) typeLoc (case (T.toLower _include_monarch, T.toLower _include_heir) of
                ("yes", "yes") -> " (rulers and heirs count)"
                ("yes", _) -> " (rulers count)"
                (_, "yes") -> " (heirs count)"
                _ -> "")
            _value
    |]

foldCompound "numOfReligion" "NumOfReligion" "nr"
    []
    [CompField "religion" [t|Text|] Nothing False
    ,CompField "value" [t|Double|] Nothing True
    ,CompField "secondary" [t|Text|] Nothing False]
    [|
        case (_religion, _secondary) of
            (Just rel, Nothing) -> do
                relLoc <- getGameL10n rel
                return $ MsgNumOfReligion (iconText rel) relLoc _value
            (Nothing, Just secondary) | T.toLower secondary == "yes" -> do
                return $ MsgNumOfReligionSecondary _value
            _ -> return $ (trace $ "Not handled in numOfReligion: " ++ show stmt) $ preMessage stmt
    |]


foldCompound "createSuccessionCrisis" "CreateSuccessionCrisis" "csc"
    []
    [CompField "attacker" [t|Text|] Nothing True
    ,CompField "defender" [t|Text|] Nothing True
    ,CompField "target"   [t|Text|] Nothing True
    ]
    [| do
        attackerLoc <- flagText (Just EU4Country) _attacker
        defenderLoc <- flagText (Just EU4Country) _defender
        targetLoc   <- flagText (Just EU4Country) _target
        return $ MsgCreateSuccessionCrisis attackerLoc defenderLoc targetLoc
    |]

-- War

data DeclareWarWithCB = DeclareWarWithCB
    {   dwcb_who :: Maybe Text
    ,   dwcb_cb :: Maybe Text
    }
newDeclareWarWithCB :: DeclareWarWithCB
newDeclareWarWithCB = DeclareWarWithCB Nothing Nothing

declareWarWithCB :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
declareWarWithCB stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_declare_war_with_cb (foldl' addLine newDeclareWarWithCB scr) where
        addLine :: DeclareWarWithCB -> GenericStatement -> DeclareWarWithCB
        addLine dwcb [pdx| $lhs = $rhs |]
            = case T.map toLower lhs of
                "who"         -> dwcb { dwcb_who = Just rhs }
                "casus_belli" -> dwcb { dwcb_cb  = Just rhs }
                _ -> dwcb
        addLine dwcb _ = dwcb
        pp_declare_war_with_cb :: DeclareWarWithCB -> PPT g m ScriptMessage
        pp_declare_war_with_cb dwcb
              = case (dwcb_who dwcb, dwcb_cb dwcb) of
                (Just who, Just cb) -> do
                    whoflag <- Doc.doc2text <$> flag (Just EU4Country) who
                    cb_loc <- getGameL10n cb
                    return (MsgDeclareWarWithCB whoflag cb_loc)
                _ -> return $ preMessage stmt
declareWarWithCB stmt = preStatement stmt

-- DLC

hasDlc :: (EU4Info g, Monad m) => StatementHandler g m
hasDlc [pdx| %_ = ?dlc |]
    = msgToPP $ MsgHasDLC dlc_icon dlc
    where
        mdlc_key = HM.lookup dlc . HM.fromList $
            [("Conquest of Paradise", "cop")
            ,("Wealth of Nations", "won")
            ,("Res Publica", "rp")
            ,("Art of War", "aow")
            ,("El Dorado", "ed")
            ,("Common Sense", "cs")
            ,("The Cossacks", "cos")
            ,("Mare Nostrum", "mn")
            ,("Rights of Man", "rom")
            ,("Mandate of Heaven", "moh")
            ,("Third Rome", "tr")
            ,("Cradle of Civilization", "coc")
            ,("Rule Britannia", "rb")
            ,("Golden Century", "goc")
            ,("Dharma", "dhr")
            ,("Emperor", "emp")
            ,("Leviathan", "lev")
            ,("Origins", "org")
            ]
        dlc_icon = maybe "" iconText mdlc_key
hasDlc stmt = preStatement stmt

-- Estates

data EstateInfluenceModifier = EstateInfluenceModifier {
        eim_estate :: Maybe Text
    ,   eim_modifier :: Maybe Text
    }
newEIM :: EstateInfluenceModifier
newEIM = EstateInfluenceModifier Nothing Nothing
hasEstateModifier :: (EU4Info g, Monad m) => (Text -> Text -> Text -> ScriptMessage) -> StatementHandler g m
hasEstateModifier msg stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_eim (foldl' addField newEIM scr)
    where
        addField :: EstateInfluenceModifier -> GenericStatement -> EstateInfluenceModifier
        addField inf [pdx| estate   = $est      |] = inf { eim_estate = Just est }
        addField inf [pdx| modifier = $modifier |] = inf { eim_modifier = Just modifier }
        addField inf _ = inf -- unknown statement
        pp_eim inf = case (eim_estate inf, eim_modifier inf) of
            (Just est, Just modifier) -> do
                loc_est <- getGameL10n est
                loc_mod <- getGameL10n modifier
                return $ msg (iconText est) loc_est loc_mod
            _ -> return (preMessage stmt)
hasEstateModifier _ stmt = preStatement stmt

data AddEstateInfluenceModifier = AddEstateInfluenceModifier {
        aeim_estate :: Maybe Text
    ,   aeim_desc :: Maybe Text
    ,   aeim_influence :: Maybe Double
    ,   aeim_duration :: Maybe Double
    } deriving Show
newAddEstateInfluenceModifier :: AddEstateInfluenceModifier
newAddEstateInfluenceModifier = AddEstateInfluenceModifier Nothing Nothing Nothing Nothing

timeOrIndef :: (EU4Info g, Monad m) => Double -> PPT g m Text
timeOrIndef n = if n < 0 then messageText MsgIndefinitely else messageText (MsgForDays n)

estateInfluenceModifier :: forall g m. (EU4Info g, Monad m) =>
    (Text -> Text -> Text -> Double -> Text -> ScriptMessage)
        -> StatementHandler g m
estateInfluenceModifier msg stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_eim (foldl' addLine newAddEstateInfluenceModifier scr)
    where
        addLine :: AddEstateInfluenceModifier -> GenericStatement -> AddEstateInfluenceModifier
        addLine aeim [pdx| estate    = $estate   |] = aeim { aeim_estate = Just estate }
        addLine aeim [pdx| desc      = $desc     |] = aeim { aeim_desc = Just desc }
        addLine aeim [pdx| influence = !inf      |] = aeim { aeim_influence = Just inf }
        addLine aeim [pdx| duration  = !duration |] = aeim { aeim_duration = Just duration }
        addLine aeim _ = aeim
        pp_eim :: AddEstateInfluenceModifier -> PPT g m ScriptMessage
        pp_eim aeim
            -- It appears that the game can handle missing description and duration, this seems unintended in 1.31.2, but here we go.
            = case (aeim_estate aeim, aeim_desc aeim, aeim_influence aeim, aeim_duration aeim) of
                (Just estate, mdesc, Just inf, mduration) -> do
                    let estate_icon = iconText estate
                    estate_loc <- getGameL10n estate
                    desc_loc <- case mdesc of
                        Just desc -> getGameL10n desc
                        _ -> return "(Missing)"
                    dur <- timeOrIndef (fromMaybe (-1) mduration)
                    return (msg estate_icon estate_loc desc_loc inf dur)
                _ -> return (preMessage stmt)
estateInfluenceModifier _ stmt = preStatement stmt

-- Trigger switch
triggerSwitch :: (EU4Info g, Monad m) => StatementHandler g m
-- A trigger switch must be of the form
-- trigger_switch = {
--  on_trigger = <statement lhs>
--  <statement rhs> = {
--      <actions>
--  }
-- }
-- where the <statement rhs> block may be repeated several times.
triggerSwitch stmt@(Statement _ OpEq (CompoundRhs
                    ([pdx| on_trigger = $condlhs |] -- assume this is first statement
                    :clauses))) = do
            statementsMsgs <- indentUp $ forM clauses $ \clause -> case clause of
                -- using next indent level, for each block <condrhs> = { ... }:
                [pdx| $condrhs = @action |] -> do
                    -- construct a fake condition to pp
                    let cond = [pdx| $condlhs = $condrhs |]
                    ((_, guardMsg):_) <- ppOne cond -- XXX: match may fail (but shouldn't)
                    guardText <- messageText guardMsg
                    -- pp the rest of the block, at the next level (done automatically by ppMany)
                    statementMsgs <- ppMany action
                    withCurrentIndent $ \i -> return $ (i, MsgTriggerSwitchClause guardText) : statementMsgs
                _ -> preStatement stmt
            withCurrentIndent $ \i -> return $ (i, MsgTriggerSwitch) : concat statementsMsgs
triggerSwitch stmt = preStatement stmt

-- | Handle @calc_true_if@ clauses, of the following form:
-- 
-- @
--  calc_true_if = {
--       <conditions>
--       amount = N
--  }
-- @
--
-- This tests the conditions, and returns true if at least N of them are true.
-- They can be individual conditions, e.g. from @celestial_empire_events.3@:
--
-- @
--  calc_true_if = {
--      accepted_culture = manchu
--      accepted_culture = chihan
--      accepted_culture = miao
--      accepted_culture = cantonese
--      ... etc. ...
--      amount = 2
--   }
-- @
--
-- or a single "all" scope, e.g. from @court_and_country_events.3@:
--
-- @
--  calc_true_if = {
--      all_core_province = {
--          owned_by = ROOT
--          culture = PREV
--      }
--      amount = 5
--  }
-- @
--
calcTrueIf :: (EU4Info g, Monad m) => StatementHandler g m
calcTrueIf stmt@[pdx| %_ = @stmts |] = do
    let (mvalStmt, rest) = extractStmt (matchLhsText "amount") stmts
        (_, rest') = extractStmt (matchLhsText "desc") rest -- ignore desc for missions
    case mvalStmt of
        Just [pdx| %_ = !count |] -> do
            restMsgs <- ppMany rest'
            withCurrentIndent $ \i ->
                return $ (i, MsgCalcTrueIf count) : restMsgs
        _ -> preStatement stmt
calcTrueIf stmt = preStatement stmt


------------------------------------------------
-- Handler for num_of_owned_provinces_**_with --
-- also used for development_in_provinces     --
------------------------------------------------

numOwnedProvincesWith :: (EU4Info g, Monad m) => (Double -> ScriptMessage) -> StatementHandler g m
numOwnedProvincesWith msg stmt@[pdx| %_ = @stmts |] = do
    let (mvalStmt, rest) = extractStmt (matchLhsText "value") stmts
    case mvalStmt of
        Just [pdx| %_ = !count |] -> do
            restMsgs <- ppMany rest
            withCurrentIndent $ \i ->
                return $ (i, msg count) : restMsgs
        Just [pdx| %_ = estate |] -> do -- FIXME: Since 1.30 this doesn't seem to do anything? (Only found in estate events)
            return []
        _ -> preStatement stmt
numOwnedProvincesWith _ stmt = preStatement stmt

-- Holy Roman Empire

-- Assume 1 <= n <= 8
hreReformLoc :: (IsGameData (GameData g), Monad m) => Int -> PPT g m Text
hreReformLoc n = getGameL10n $ case n of
    1 -> "reichsreform_title"
    2 -> "reichsregiment_title"
    3 -> "hofgericht_title"
    4 -> "gemeinerpfennig_title"
    5 -> "landfriede_title"
    6 -> "erbkaisertum_title"
    7 -> "privilegia_de_non_appelando_title"
    8 -> "renovatio_title"
    _ -> error "called hreReformLoc with n < 1 or n > 8"

hreReformLevel :: (EU4Info g, Monad m) => StatementHandler g m
hreReformLevel [pdx| %_ = !level |] | level >= 0, level <= 8
    = if level == 0
        then msgToPP MsgNoHREReforms
        else msgToPP . MsgHREPassedReform =<< hreReformLoc level
hreReformLevel stmt = preStatement stmt

-- Religion

religionYears :: (EU4Info g, Monad m) => StatementHandler g m
religionYears [pdx| %_ = { $rel = !years } |]
    = do
        let rel_icon = iconText rel
        rel_loc <- getGameL10n rel
        msgToPP $ MsgReligionYears rel_icon rel_loc years
religionYears stmt = preStatement stmt

-- Government

govtRank :: (EU4Info g, Monad m) => StatementHandler g m
govtRank [pdx| %_ = !level |]
    = case level :: Int of
        1 -> msgToPP MsgRankDuchy -- unlikely, but account for it anyway
        2 -> msgToPP MsgRankKingdom
        3 -> msgToPP MsgRankEmpire
        _ -> error "impossible: govtRank matched an invalid rank number"
govtRank stmt = preStatement stmt

setGovtRank :: (EU4Info g, Monad m) => StatementHandler g m
setGovtRank [pdx| %_ = !level |] | level `elem` [1..3]
    = case level :: Int of
        1 -> msgToPP MsgSetRankDuchy
        2 -> msgToPP MsgSetRankKingdom
        3 -> msgToPP MsgSetRankEmpire
        _ -> error "impossible: setGovtRank matched an invalid rank number"
setGovtRank stmt = preStatement stmt

numProvinces :: (EU4Info g, Monad m) =>
    Text
        -> (Text -> Text -> Double -> ScriptMessage)
        -> StatementHandler g m
numProvinces micon msg [pdx| $what = !amt |] = do
    what_loc <- getGameL10n what
    msgToPP (msg (iconText micon) what_loc amt)
numProvinces _ _ stmt = preStatement stmt

withFlagOrProvince :: (EU4Info g, Monad m) =>
    (Text -> ScriptMessage)
        -> (Text -> ScriptMessage)
        -> StatementHandler g m
withFlagOrProvince countryMsg _ stmt@[pdx| %_ = ?_ |]
    = withFlag countryMsg stmt
withFlagOrProvince countryMsg _ stmt@[pdx| %_ = $_:$_ |]
    = withFlag countryMsg stmt -- could be either
withFlagOrProvince _ provinceMsg stmt@[pdx| %_ = !(_ :: Double) |]
    = withProvince provinceMsg stmt
withFlagOrProvince _ _ stmt = preStatement stmt

withFlagOrProvinceEU4Scope :: (EU4Info g, Monad m) =>
    (Text -> ScriptMessage)
        -> (Text -> ScriptMessage)
        -> (Text -> ScriptMessage)
        -> (Text -> ScriptMessage)
        -> StatementHandler g m
withFlagOrProvinceEU4Scope bothCountryMsg scopeCountryParamGeogMsg scopeGeogParamCountryMsg bothGeogMsg stmt = do
    mscope <- getCurrentScope
    -- If no scope, assume country.
    if fromMaybe False (isGeographic <$> mscope) then
        withFlagOrProvince scopeGeogParamCountryMsg bothGeogMsg stmt
    else
        withFlagOrProvince bothCountryMsg scopeCountryParamGeogMsg stmt

tradeMod :: (EU4Info g, Monad m) => StatementHandler g m
tradeMod stmt@[pdx| %_ = ?_ |]
    = withLocAtom2 MsgTradeMod MsgHasModifier stmt
tradeMod stmt@[pdx| %_ = @scr |] = msgToPP =<< pp_tm (foldl' addLine newTA scr)
    where
        addLine :: TextAtom -> GenericStatement -> TextAtom
        addLine ta [pdx| who = ?who |]
            = ta { ta_what = Just who }
        addLine ta [pdx| $label = ?at |]
            | label == "key" || label == "name"
            = ta { ta_atom = Just at }
        addLine ta scr = (trace ("tradeMod: Ignoring " ++ show scr)) $ ta

        pp_tm ta = case (ta_what ta, ta_atom ta) of
            (Just who, Just key) -> do
                whoText <- flagText (Just EU4Country) who
                keyText <- getGameL10n key
                return $ MsgHasTradeModifier "" whoText keyText
            _ -> return $ preMessage stmt
tradeMod stmt = preStatement stmt

isMonth :: (EU4Info g, Monad m) => StatementHandler g m
isMonth [pdx| %_ = !(num :: Int) |] | num >= 0, num <= 11
    = do
        month_loc <- getGameL10n $ case num of
            0 -> "January" -- programmer counting -_-
            1 -> "February"
            2 -> "March"
            3 -> "April"
            4 -> "May"
            5 -> "June"
            6 -> "July"
            7 -> "August"
            8 -> "September"
            9 -> "October"
            10 -> "November"
            11 -> "December"
            _ -> error "impossible: tried to localize bad month number"
        msgToPP $ MsgIsMonth month_loc
isMonth stmt = preStatement stmt

range :: (EU4Info g, Monad m) => StatementHandler g m
range stmt@[pdx| %_ = !(_ :: Double) |]
    = numericIcon "colonial range" MsgGainColonialRange stmt
range stmt = withFlag MsgIsInColonialRange stmt

area :: (EU4Info g, Monad m) => StatementHandler g m
area stmt@[pdx| %_ = @_ |] = scope EU4Geographic $ compoundMessage MsgArea stmt
area stmt                  = locAtomTagOrProvince (const MsgAreaIs) MsgAreaIsAs stmt

-- Currently dominant_culture only appears in decisions/Cultural.txt
-- (dominant_culture = capital).
dominantCulture :: (EU4Info g, Monad m) => StatementHandler g m
dominantCulture [pdx| %_ = capital |] = msgToPP MsgCapitalCultureDominant
dominantCulture stmt = preStatement stmt

customTriggerTooltip :: (EU4Info g, Monad m) => StatementHandler g m
customTriggerTooltip [pdx| %_ = @scr |]
    -- ignore the custom tooltip
    = let rest = flip filter scr $ \stmt -> case stmt of
            [pdx| tooltip = %_ |] -> False
            _ -> True
      in indentDown $ ppMany rest
customTriggerTooltip stmt = preStatement stmt

piety :: (EU4Info g, Monad m) => StatementHandler g m
piety stmt@[pdx| %_ = !amt |]
    = numericIcon (case amt `compare` (0::Double) of
        LT -> "lack of piety"
        _  -> "being pious")
      MsgPiety stmt
piety stmt = preStatement stmt

dynasty :: (EU4Info g, Monad m) => StatementHandler g m
dynasty stmt@[pdx| %_ = ?str |] = do
    nflag <- flag (Just EU4Country) str
    if isTag str || isPronoun str then
        msgToPP $ MsgRulerIsSameDynasty (Doc.doc2text nflag)
    else
        msgToPP $ MsgRulerIsDynasty str
dynasty stmt = (trace (show stmt)) $ preStatement stmt

----------------------
-- Idea group ideas --
----------------------

hasIdea :: (EU4Info g, Monad m) =>
    (Text -> Int -> ScriptMessage)
        -> StatementHandler g m
hasIdea msg stmt@[pdx| $lhs = !n |] | n >= 1, n <= 7 = do
    groupTable <- getIdeaGroups
    let mideagroup = HM.lookup lhs groupTable
    case mideagroup of
        Nothing -> preStatement stmt -- unknown idea group
        Just grp -> do
            let idea = ig_ideas grp !! (n - 1)
                ideaKey = idea_name idea
            idea_loc <- getGameL10n ideaKey
            msgToPP (msg idea_loc n)
hasIdea _ stmt = preStatement stmt

-----------
-- Trust --
-----------

data Trust = Trust
        {   tr_whom :: Maybe Text
        ,   tr_amount :: Maybe Double
        ,   tr_mutual :: Bool
        }
newTrust :: Trust
newTrust = Trust Nothing Nothing False
trust :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
trust stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_trust =<< foldM addLine newTrust scr
    where
        addLine :: Trust -> GenericStatement -> PPT g m Trust
        addLine tr [pdx| who = $whom |] = do
            whom' <- Doc.doc2text <$> pronoun (Just EU4Country) whom
            return tr { tr_whom = Just whom' }
        addLine tr [pdx| value = !amt |]
            = return tr { tr_amount = Just amt }
        addLine tr [pdx| mutual = yes |]
            = return tr { tr_mutual = True }
        addLine tr _ = return tr
        pp_trust tr
            | (Just whom, Just amt) <- (tr_whom tr, tr_amount tr)
              = return $ (if tr_mutual tr then MsgAddTrustMutual else MsgAddTrust)
                          whom amt
            | otherwise = return (preMessage stmt)
trust stmt = preStatement stmt

----------------------------------------
-- Government form-specific mechanics --
----------------------------------------

-- Currently this form only affects Russian government.

gpMechanicTable :: HashMap (Text, MonarchPower) (Double -> ScriptMessage)
gpMechanicTable = HM.fromList
    [(("russian_mechanic", Administrative), MsgSudebnikProgress)
    ,(("russian_mechanic", Diplomatic), MsgOprichninaProgress)
    ,(("russian_mechanic", Military), MsgStreltsyProgress)
    ]

data GovernmentPower = GovernmentPower
        {   gp_mechanic :: Maybe Text
        ,   gp_category :: Maybe MonarchPower
        ,   gp_amount :: Maybe Double
        }
newGP :: GovernmentPower
newGP = GovernmentPower Nothing Nothing Nothing
governmentPower :: (EU4Info g, Monad m) => StatementHandler g m
governmentPower stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_gp (foldl' addLine newGP scr)
    where
        addLine :: GovernmentPower -> GenericStatement -> GovernmentPower
        addLine gp [pdx| government_mechanic = $mechanic |]
            = gp { gp_mechanic = Just mechanic }
        addLine gp [pdx| which = $cat      |]
            = case cat of
                "ADM" -> gp { gp_category = Just Administrative }
                "DIP" -> gp { gp_category = Just Diplomatic }
                "MIL" -> gp { gp_category = Just Military }
                _ -> gp
        addLine gp [pdx| amount = !amt |]
            = gp { gp_amount = Just amt }
        addLine gp _ = gp
        pp_gp gp
            | (Just mech, Just cat, Just amt) <- (gp_mechanic gp, gp_category gp, gp_amount gp),
              Just powmsg <- HM.lookup (mech, cat) gpMechanicTable
              = return (powmsg amt)
            | otherwise = return (preMessage stmt)
governmentPower stmt = preStatement stmt

----------------------
-- Employed advisor --
----------------------

data EmployedAdvisor = EmployedAdvisor
        {   ea_category :: Maybe MonarchPower
        ,   ea_type :: Maybe Text
        ,   ea_male :: Maybe Bool
        ,   ea_culture :: Maybe Text
        ,   ea_religion :: Maybe Text
        }
        deriving Show
newEA :: EmployedAdvisor
newEA = EmployedAdvisor Nothing Nothing Nothing Nothing Nothing

employedAdvisor :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
employedAdvisor stmt@[pdx| %_ = @scr |] = do
    currentFile <- withCurrentFile $ \f -> return f
    let addLine :: EmployedAdvisor -> GenericStatement -> EmployedAdvisor
        addLine ea [pdx| category = $cat |]
            = case cat of
                "ADM" -> ea { ea_category = Just Administrative }
                "DIP" -> ea { ea_category = Just Diplomatic }
                "MIL" -> ea { ea_category = Just Military }
                _ -> ea
        addLine ea [pdx| type = $typ |]
            = ea { ea_type = Just typ }
        addLine ea [pdx| is_male = $is_male |]
            = case T.toLower is_male of
                "yes" -> ea { ea_male = Just True }
                "no" -> ea { ea_male = Just False }
                _ -> ea
        addLine ea [pdx| is_female = $is_female |]
            = case T.toLower is_female of
                "yes" -> ea { ea_male = Just False }
                "no" -> ea { ea_male = Just True }
                _ -> ea
        addLine ea [pdx| culture = %cul |]
            = ea { ea_culture = textRhs cul }
        addLine ea [pdx| religion = %rel |]
            = ea { ea_religion = textRhs rel }
        addLine ea line = (trace $ ("Unhandled employed_advisor condition in " ++ currentFile ++ ": " ++ show line)) $ ea


        pp_employed_advisor :: EmployedAdvisor -> PPT g m IndentedMessages
        pp_employed_advisor ea = do
            body <- indentUp (unfoldM pp_employed_advisor_attrib ea)
            if null body then
                msgToPP MsgEmployedAdvisor
            else
                liftA2 (++)
                    (msgToPP MsgEmployedAdvisorWhere)
                    (pure body)

        pp_employed_advisor_attrib :: EmployedAdvisor -> PPT g m (Maybe (IndentedMessage, EmployedAdvisor))
        pp_employed_advisor_attrib ea@EmployedAdvisor { ea_category = Just cat } = do
            let mt = case cat of
                    Administrative -> MsgEmployedAdvisorAdmin
                    Diplomatic -> MsgEmployedAdvisorDiplo
                    Military -> MsgEmployedAdvisorMiltary
            [msg] <- msgToPP mt
            return (Just (msg, ea { ea_category = Nothing }))
        pp_employed_advisor_attrib ea@EmployedAdvisor { ea_type = Just typ } = do
            (t, i) <- tryLocAndIcon typ
            [msg] <- msgToPP $ MsgEmployedAdvisorType t i
            return (Just (msg, ea { ea_type = Nothing }))
        pp_employed_advisor_attrib ea@EmployedAdvisor { ea_male = Just male } = do
            [msg] <- msgToPP $ MsgEmployedAdvisorMale male
            return (Just (msg, ea { ea_male = Nothing }))
        pp_employed_advisor_attrib ea@EmployedAdvisor { ea_culture = Just culture } =
            if isPronoun culture then do
                text <- Doc.doc2text <$> pronoun Nothing culture
                [msg] <- msgToPP $ MsgCultureIsAs text
                return (Just (msg, ea { ea_culture = Nothing }))
            else do
                text <- getGameL10n culture
                [msg] <- msgToPP $ MsgCultureIs text
                return (Just (msg, ea { ea_culture = Nothing }))
        -- TODO: Better localization (neither heretic nor heathen seem to be in the localization files)
        pp_employed_advisor_attrib ea@EmployedAdvisor { ea_religion = Just "heretic" } = do
            [msg] <- msgToPP $ MsgReligion (iconText "tolerance heretic") "hertical"
            return (Just (msg, ea { ea_religion = Nothing }))
        pp_employed_advisor_attrib ea@EmployedAdvisor { ea_religion = Just "heathen" } = do
            [msg] <- msgToPP $ MsgReligion (iconText "tolerance heathen") "heathen"
            return (Just (msg, ea { ea_religion = Nothing }))
        pp_employed_advisor_attrib ea@EmployedAdvisor { ea_religion = Just religion } =
            if isPronoun religion then do
                text <- Doc.doc2text <$> pronoun Nothing religion
                [msg] <- msgToPP $ MsgSameReligion text
                return (Just (msg, ea { ea_religion = Nothing }))
            else do
                (t, i) <- tryLocAndIcon religion
                [msg] <- msgToPP $ MsgReligion i t
                return (Just (msg, ea { ea_religion = Nothing }))
        pp_employed_advisor_attrib _ = return Nothing

    pp_employed_advisor $ foldl' addLine newEA scr
employedAdvisor stmt = preStatement stmt

------------------------------
-- Handler for xxx_variable --
------------------------------

data SetVariable = SetVariable
        { sv_which  :: Maybe Text
        , sv_which2 :: Maybe Text
        , sv_value  :: Maybe Double
        }

newSV :: SetVariable
newSV = SetVariable Nothing Nothing Nothing

setVariable :: forall g m. (EU4Info g, Monad m) =>
    (Text -> Text -> ScriptMessage) ->
    (Text -> Double -> ScriptMessage) ->
    StatementHandler g m
setVariable msgWW msgWV stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_sv (foldl' addLine newSV scr)
    where
        addLine :: SetVariable -> GenericStatement -> SetVariable
        addLine sv [pdx| which = ?val |]
            = if isNothing (sv_which sv) then
                sv { sv_which = Just val }
              else
                sv { sv_which2 = Just val }
        addLine sv [pdx| value = !val |]
            = sv { sv_value = Just val }
        addLine sv _ = sv
        toTT :: Text -> Text
        toTT t = "<tt>" <> t <> "</tt>"
        pp_sv :: SetVariable -> PPT g m ScriptMessage
        pp_sv sv = case (sv_which sv, sv_which2 sv, sv_value sv) of
            (Just v1, Just v2, Nothing) -> do return $ msgWW (toTT v1) (toTT v2)
            (Just v,  Nothing, Just val) -> do return $ msgWV (toTT v) val
            _ ->  do return $ preMessage stmt
setVariable _ _ stmt = preStatement stmt

---------------------------
-- Handler for is_in_war --
---------------------------

isInWar :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
isInWar stmt@[pdx| %_ = @scr |]
    = withCurrentIndent $ \i -> do
        script_pp'd <- indentUp (concat <$> mapM handleLine scr)
        return ((i, MsgIsInWar) : script_pp'd)
    where
        handleLine :: (EU4Info g, Monad m) => StatementHandler g m
        handleLine [pdx| duration = !dur |] = msgToPP $ MsgDurationAtLeast dur
        handleLine [pdx| casus_belli = $cb |] = msgToPP =<< do
            cbText <- getGameL10n cb
            return $ MsgCasusBelliIs cbText
        handleLine stmt@[pdx| $what = $who |] = msgToPP =<< do
            whoText <- flagText (Just EU4Country) who
            return $ case T.toLower what of
                        "attacker_leader" -> MsgIsAttackerWarLeader whoText
                        "defender_leader" -> MsgIsDefenderWarLeader whoText
                        "attackers" -> MsgIsAttacker whoText
                        "defenders" -> MsgIsDefender whoText
                        _ -> (trace $ "is_in_war: Unhandled Statement " ++ (show stmt)) $ preMessage stmt
        handleLine stmt = (trace $ "is_in_war: Unhandled statement " ++ (show stmt)) $ preStatement stmt
isInWar stmt = preStatement stmt

------------------------------------------
-- Handler for has_government_attribute --
------------------------------------------
hasGovermentAttribute :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
hasGovermentAttribute stmt@[pdx| %_ = $mech |]
    = msgToPP =<< MsgGovernmentHasAttribute <$> getGameL10n ("mechanic_" <> mech <> "_yes")
hasGovermentAttribute stmt = trace ("warning: not handled for has_government_attribute: " ++ (show stmt)) $ preStatement stmt



-------------------------------------
-- Handler for define_general etc. --
-------------------------------------
data MilitaryLeader = MilitaryLeader
        {   ml_tradition :: Maybe Double
        ,   ml_shock :: Maybe Double
        ,   ml_fire :: Maybe Double
        ,   ml_manuever :: Maybe Double
        ,   ml_siege :: Maybe Double
        ,   ml_name :: Maybe Text
        ,   ml_female :: Maybe Bool
        ,   ml_trait :: Maybe Text
        }
        deriving Show
newML :: MilitaryLeader
newML = MilitaryLeader Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing

-- Also used for hasLeaderWith
pp_mil_leader_attrib :: forall g m. (EU4Info g, Monad m) => Bool -> MilitaryLeader -> PPT g m (Maybe (IndentedMessage, MilitaryLeader))
pp_mil_leader_attrib naval ml =
    let msgShock     = (if naval then MsgNavalLeaderShock (iconText "naval leader shock") else MsgLandLeaderShock (iconText "land leader shock"))
        msgFire      = (if naval then MsgNavalLeaderFire (iconText "naval leader fire") else MsgLandLeaderFire (iconText "land leader fire"))
        msgManuever  = (if naval then MsgNavalLeaderManeuver (iconText "naval leader maneuver") else MsgLandLeaderManeuver (iconText "land leader maneuver"))
        msgSiege     = (if naval then MsgNavalLeaderSiege (iconText "blockade") else MsgLandLeaderSiege (iconText "land leader siege"))

        pp_mil_leader_attrib' :: MilitaryLeader -> PPT g m (Maybe (IndentedMessage, MilitaryLeader))
        pp_mil_leader_attrib' ml@MilitaryLeader { ml_tradition = Just trad } = do
            [msg] <- msgToPP $ MsgLeaderTradition naval trad
            return (Just (msg, ml { ml_tradition = Nothing }))
        pp_mil_leader_attrib' ml@MilitaryLeader { ml_shock = Just shock } = do
            [msg] <- msgToPP $ msgShock shock
            return (Just (msg, ml { ml_shock = Nothing }))
        pp_mil_leader_attrib' ml@MilitaryLeader { ml_fire = Just fire } = do
            [msg] <- msgToPP $ msgFire fire
            return (Just (msg, ml { ml_fire = Nothing }))
        pp_mil_leader_attrib' ml@MilitaryLeader { ml_manuever = Just manuever } = do
            [msg] <- msgToPP $ msgManuever manuever
            return (Just (msg, ml { ml_manuever = Nothing }))
        pp_mil_leader_attrib' ml@MilitaryLeader { ml_siege = Just siege } = do
            [msg] <- msgToPP $ msgSiege siege
            return (Just (msg, ml { ml_siege = Nothing }))
        pp_mil_leader_attrib' ml@MilitaryLeader { ml_name = Just name } = do
            [msg] <- msgToPP $ MsgNamed name
            return (Just (msg, ml { ml_name = Nothing }))
        pp_mil_leader_attrib' ml@MilitaryLeader { ml_female = Just True } = do
            [msg] <- msgToPP $ MsgWithGender False
            return (Just (msg, ml { ml_female = Nothing }))
        pp_mil_leader_attrib' ml@MilitaryLeader { ml_trait = Just trait } = do
            text <- getGameL10n trait
            [msg] <- msgToPP $ MsgMilitaryLeaderTrait text
            return (Just (msg, ml { ml_trait = Nothing }))
        pp_mil_leader_attrib' _ = return Nothing
    in
        pp_mil_leader_attrib' ml


defineMilitaryLeader :: forall g m. (EU4Info g, Monad m) => Text -> Bool -> (Text -> ScriptMessage) -> StatementHandler g m
defineMilitaryLeader icon naval headline stmt@[pdx| %_ = @scr |] = do
    currentFile <- withCurrentFile $ \f -> return f
    let addLine :: MilitaryLeader -> GenericStatement -> MilitaryLeader
        addLine ml [pdx| tradition = %rhs |]
            = ml { ml_tradition = floatRhs rhs }
        addLine ml [pdx| shock = %rhs |]
            = ml { ml_shock = floatRhs rhs }
        addLine ml [pdx| fire = %rhs |]
            = ml { ml_fire = floatRhs rhs }
        addLine ml [pdx| manuever = %rhs |]
            = ml { ml_manuever = floatRhs rhs }
        addLine ml [pdx| siege = %rhs |]
            = ml { ml_siege = floatRhs rhs }
        addLine ml [pdx| name = %name |]
            = ml { ml_name = textRhs name }
        addLine ml [pdx| female = yes |]
            = ml { ml_female = Just True }
        addLine ml [pdx| trait = %trait |]
            = ml { ml_trait = textRhs trait }
        addLine ml line = (trace $ ("Unhandled military leader condition in " ++ currentFile ++ ": " ++ show line)) $ ml

        pp_mil_leader :: MilitaryLeader -> PPT g m IndentedMessages
        pp_mil_leader ml = do
            body <- indentUp (unfoldM (pp_mil_leader_attrib naval) ml)
            liftA2 (++)
                (msgToPP $ headline (iconText icon))
                (pure body)

    pp_mil_leader $ foldl' addLine newML scr
defineMilitaryLeader _ _ _ stmt = preStatement stmt

createMilitaryLeader :: forall g m. (EU4Info g, Monad m) => Text -> Bool -> (Text -> Double -> ScriptMessage) -> (Text -> ScriptMessage) -> StatementHandler g m
createMilitaryLeader icon naval msgWithTradition msgHeadline stmt@[pdx| $_ = @stmts |] =
    let (_, rest) = extractStmt (matchLhsText "culture") stmts -- FIXME: Ignoring culture when only combined with tradition
        (mtrad, rest') = extractStmt (matchLhsText "tradition") rest in
        case mtrad of
            Just ([pdx| %_ = !tradition |]) | length rest' == 0 -> msgToPP $ msgWithTradition (iconText icon) tradition
            _ -> defineMilitaryLeader icon naval msgHeadline stmt
createMilitaryLeader _ _ _ _ stmt = preStatement stmt

--------------------------------
-- Handler for set_saved_name --
--------------------------------

data SetSavedName = SetSavedName
        { ssn_key  :: Maybe Text
        , ssn_type :: Maybe Text
        , ssn_scope :: Maybe Text
        , ssn_female :: Bool
        }

newSSN :: SetSavedName
newSSN = SetSavedName Nothing Nothing Nothing False

setSavedName :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
setSavedName stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_ssn (foldl' addLine newSSN scr)
    where
        addLine :: SetSavedName -> GenericStatement -> SetSavedName
        addLine ssn [pdx| key = ?val |]
            = ssn { ssn_key = Just val }
        addLine ssn [pdx| type = ?typ |]
            = ssn { ssn_type = Just (T.toUpper typ) }
        addLine ssn [pdx| scope = ?scope |]
            = ssn { ssn_scope = Just scope }
        addLine ssn [pdx| female = ?val |]
            = case T.toLower val of
                "yes" -> ssn { ssn_female = True }
                _ -> ssn
        addLine ssn stmt = (trace $ "Unknown in set_saved_name" ++ show stmt) $ ssn
        pp_ssn :: SetSavedName -> PPT g m ScriptMessage
        pp_ssn ssn = do
            typeText <- maybeM getGameL10n (ssn_type ssn)
            scopeText <- maybeM (\n -> if isPronoun n then Doc.doc2text <$> pronoun Nothing n else return $ "<tt>" <> n <> "</tt>") (ssn_scope ssn)
            case (ssn_key ssn, typeText, scopeText) of
                (Just key, Just typ, Nothing) -> return $ MsgSetSavedName key typ (ssn_female ssn)
                (Just key, Just typ, Just scope) -> return $ MsgSetSavedNameScope key typ scope (ssn_female ssn)
                _ -> return $ preMessage stmt
setSavedName stmt = (trace (show stmt)) $ preStatement stmt

---------------------------------
-- Handler for privateer_power --
---------------------------------

privateerPower :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
privateerPower stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_pp (parseTV "country" "share" scr)
    where
        pp_pp :: TextValue -> PPT g m ScriptMessage
        pp_pp tv = case (tv_what tv, tv_value tv) of
            (Just what, Just val) -> do
                what_loc <- flag (Just EU4Country) what
                return $ MsgPrivateerPowerCountry (Doc.doc2text what_loc) val
            (Nothing, Just val) -> do
                return $ MsgPrivateerPower val
            _ -> return $ preMessage stmt
privateerPower stmt = preStatement stmt

-------------------------------
-- Handler for trading_bonus --
-------------------------------
tradingBonus :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
tradingBonus stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_tb (parseTA "trade_goods" "value" scr)
    where
        pp_tb :: TextAtom -> PPT g m ScriptMessage
        pp_tb ta = case (ta_what ta, ta_atom ta) of
            (Just what, Just atom) | T.toLower atom == "yes" -> do
                what_loc <- getGameL10n what
                return $ MsgTradingBonus (iconText what) what_loc
            _ -> return $ preMessage stmt
tradingBonus stmt = preStatement stmt

-----------------------------------
-- Handler for estate privileges --
-----------------------------------
estatePrivilege :: forall g m. (EU4Info g, Monad m) => (Text -> ScriptMessage) -> StatementHandler g m
estatePrivilege msg [pdx| %_ = @scr |] | length scr == 1 = estatePrivilege' (head scr)
    where
        estatePrivilege' :: GenericStatement -> PPT g m IndentedMessages
        estatePrivilege' [pdx| privilege = $priv |] = do
            locText <- getGameL10n priv
            msgToPP $ msg locText
        estatePrivilege' stmt = preStatement stmt
estatePrivilege _ stmt = preStatement stmt


------------------------------------------------------
-- Handler for has_trade_company_investment_in_area --
------------------------------------------------------
foldCompound "hasTradeCompanyInvestment" "HasTradeCompanyInvestment" "htci"
    []
    [CompField "investor" [t|Text|] Nothing True
    ,CompField "investment" [t|Text|] Nothing False
    ,CompField "count_one_per_area" [t|Text|] Nothing False
    ]
    [| do
        investorLoc <- flagText (Just EU4Country) _investor
        case (_investment, _count_one_per_area) of
            (Just investment, Nothing) -> do
                (icon, desc) <- tryLocAndIcon investment
                return $ MsgHasTradeCompanyInvestmentInArea icon desc investorLoc
            (Nothing, Just yn) | T.toLower yn == "yes" ->
                return $ MsgHasTradeCompanyInvestmentInState investorLoc
            _ -> return $ (trace $ ("Unsupported has_trade_company_investment_in_area: " ++ show stmt)) $ preMessage stmt
    |]

----------------------------------------
-- Handler for trading_policy_in_node --
----------------------------------------
tradingPolicyInNode :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
tradingPolicyInNode stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_tpin (parseTA "node" "policy" scr)
    where
        pp_tpin :: TextAtom -> PPT g m ScriptMessage
        pp_tpin ta = case (ta_what ta, ta_atom ta) of
            (Just node, Just policy) -> do
                nodeLoc <- Doc.doc2text <$> allowPronoun (Just EU4TradeNode) (fmap Doc.strictText . getGameL10n) node
                case T.toLower policy of
                    "any" -> return $ MsgTradingPolicyInNodeAny nodeLoc
                    _ -> do
                        policyLoc <- getGameL10n policy
                        return $ MsgTradingPolicyInNode nodeLoc policyLoc
                --traceM $ "Node: " ++ (T.unpack $ nodeLoc) ++ " Policy: " ++ (T.unpack $ policyLoc)
                -- NOTE: policy can be "any"
                --return $ preMessage stmt
            _ -> return $ preMessage stmt
tradingPolicyInNode stmt = preStatement stmt

--------------------------------------------------------------------------
-- Handler for generate_advisor_of_type_and_semi_random_religion_effect --
--------------------------------------------------------------------------

data RandomAdvisor = RandomAdvisor
        { ra_type :: Maybe Text
        , ra_type_non_state :: Maybe Text
        , ra_scaled_skill :: Bool
        , ra_skill :: Maybe Double
        , ra_discount :: Bool
        } deriving Show

newRA :: RandomAdvisor
newRA = RandomAdvisor Nothing Nothing False Nothing False

randomAdvisor :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
randomAdvisor stmt@[pdx| %_ = @scr |] = pp_ra (foldl' addLine newRA scr)
    where
        addLine :: RandomAdvisor -> GenericStatement -> RandomAdvisor
        addLine ra [pdx| advisor_type = $typ |] = ra { ra_type = Just typ }
        addLine ra [pdx| advisor_type_if_not_state= $typ |] = ra { ra_type_non_state = Just typ }
        addLine ra [pdx| scaled_skill = $yn |] = ra { ra_scaled_skill = T.toLower yn == "yes" }
        addLine ra [pdx| skill = !skill |] = ra { ra_skill = Just skill }
        addLine ra [pdx| discount = $yn |] = ra { ra_discount = T.toLower yn == "yes" }
        addLine ra stmt = (trace $ "randomAdvisor: Ignoring " ++ (show stmt)) $ ra

        pp_ra_attrib :: RandomAdvisor -> PPT g m (Maybe (IndentedMessage, RandomAdvisor))
        pp_ra_attrib ra@RandomAdvisor{ra_type_non_state = Just typ} | T.toLower typ /= maybe "" T.toLower (ra_type ra) = do
            (t, i) <- tryLocAndIcon typ
            [msg] <- msgToPP $ MsgRandomAdvisorNonState i t
            return (Just (msg, ra { ra_type_non_state = Nothing }))
        pp_ra_attrib ra@RandomAdvisor{ra_skill = Just skill} = do
            [msg] <- msgToPP $ MsgRandomAdvisorSkill skill
            return (Just (msg, ra { ra_skill = Nothing }))
        pp_ra_attrib ra@RandomAdvisor{ra_scaled_skill = True} = do
            [msg] <- msgToPP $ MsgRandomAdvisorScaledSkill
            return (Just (msg, ra { ra_scaled_skill = False }))
        pp_ra_attrib ra = return Nothing

        pp_ra :: RandomAdvisor -> PPT g m IndentedMessages
        pp_ra ra@RandomAdvisor{ra_type = Just typ, ra_discount = discount} = do
            (t, i) <- tryLocAndIcon typ
            body <- indentUp (unfoldM pp_ra_attrib ra)
            liftA2 (++)
                (msgToPP $ MsgRandomAdvisor i t discount)
                (pure body)
        pp_ra ra = (trace $ show ra) $ preStatement stmt

randomAdvisor stmt = preStatement stmt

-----------------------------
-- Handler for kill_leader --
-----------------------------
killLeader :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
killLeader stmt@[pdx| %_ = @scr |] =
    let
        (mtype, rest) = extractStmt (matchLhsText "type") scr
    in
        case (mtype, rest) of
            (Just (Statement _ _ (StringRhs name)), []) -> msgToPP $ MsgKillLeaderNamed (iconText "general") name
            (Just (Statement _ _ (GenericRhs typ _)), []) ->
                case T.toLower typ of
                    "random" -> msgToPP $ MsgKillLeaderRandom (iconText "general")
                    t -> do
                        locType <- getGameL10n t
                        msgToPP $ MsgKillLeaderType (iconText t) locType
            _ -> (trace $ "Not handled in killLeader: " ++ (show stmt)) $ preStatement stmt
killLeader stmt = (trace $ "Not handled in killLeader: " ++ (show stmt)) $ preStatement stmt

---------------------------------------------
-- Handler for add_estate_loyalty_modifier --
---------------------------------------------

data EstateLoyaltyModifier = EstateLoyaltyModifier
        { elm_estate  :: Maybe Text
        , elm_desc :: Maybe Text
        , elm_loyalty :: Maybe Double
        , elm_duration :: Maybe Double
        } deriving Show

newELM :: EstateLoyaltyModifier
newELM = EstateLoyaltyModifier Nothing Nothing Nothing Nothing

addEstateLoyaltyModifier :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
addEstateLoyaltyModifier stmt@[pdx| %_ = @scr |] = msgToPP =<< pp_elm (foldl' addLine newELM scr)
    where
        addLine :: EstateLoyaltyModifier -> GenericStatement -> EstateLoyaltyModifier
        addLine elm [pdx| estate = ?val |]
            = elm { elm_estate = Just val }
        addLine elm [pdx| desc = ?val |]
            = elm { elm_desc = Just val }
        addLine elm [pdx| loyalty = %val |]
            = elm { elm_loyalty = floatRhs val }
        addLine elm [pdx| duration = %val |]
            = elm { elm_duration = floatRhs val }
        addLine elm stmt = (trace $ "Unknown in add_estate_loyalty_modifier " ++ show stmt) $ elm
        pp_elm :: EstateLoyaltyModifier -> PPT g m ScriptMessage
        -- It appears that the game can handle missing description and duration, this seems unintended in 1.31.2, but here we go.
        pp_elm EstateLoyaltyModifier { elm_estate = Just estate, elm_desc = mdesc, elm_loyalty = Just loyalty, elm_duration = mduration } = do
            estateLoc <- getGameL10n estate
            descLoc <- case mdesc of
                Just desc -> getGameL10n desc
                _ -> return "(Missing)"
            return $ MsgAddEstateLoyaltyModifier (iconText estate) estateLoc descLoc (fromMaybe (-1) mduration) loyalty
        pp_elm elm = return $ (trace $ "Missing info for add_estate_loyalty_modifier " ++ show elm ++ " " ++ (show stmt)) $ preMessage stmt
addEstateLoyaltyModifier stmt = (trace $ "Not handled in addEstateLoyaltyModifier: " ++ (show stmt)) $ preStatement stmt



-------------------------------------
-- Handler for export_to_variable  --
-------------------------------------

data ExportVariable = ExportVariable
        { ev_which  :: Maybe Text
        , ev_value :: Maybe Text
        , ev_who :: Maybe Text
        } deriving Show

newEV :: ExportVariable
newEV = ExportVariable Nothing Nothing Nothing

exportVariable :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
exportVariable stmt@[pdx| %_ = @scr |] = msgToPP =<< pp_ev (foldl' addLine newEV scr)
    where
        addLine :: ExportVariable -> GenericStatement -> ExportVariable
        addLine ev [pdx| which = ?val |]
            = ev { ev_which = Just val }
        addLine ev [pdx| variable_name = ?val |]
            = ev { ev_which = Just val }
        addLine ev [pdx| value = ?val |]
            = ev { ev_value = Just val }
        addLine ev [pdx| who = ?val |]
            = ev { ev_who = Just val }
        addLine ev stmt = (trace $ "Unknown in export_to_variable " ++ show stmt) $ ev
        pp_ev :: ExportVariable -> PPT g m ScriptMessage
        pp_ev ExportVariable { ev_which = Just which, ev_value = Just value, ev_who = Nothing } =
            return $ MsgExportVariable which value
        pp_ev ExportVariable { ev_which = Just which, ev_value = Just value, ev_who = Just who } = do
            whoLoc <- Doc.doc2text <$> allowPronoun (Just EU4Country) (fmap Doc.strictText . getGameL10n) who
            return $ MsgExportVariableWho which value whoLoc
        pp_ev ev = return $ (trace $ "Missing info for export_to_variable " ++ show ev ++ " " ++ (show stmt)) $ preMessage stmt
exportVariable stmt = (trace $ "Not handled in export_to_variable: " ++ (show stmt)) $ preStatement stmt

-----------------------------------
-- Handler for (set_)ai_attitude --
-----------------------------------
aiAttitude :: forall g m. (EU4Info g, Monad m) => (Text -> Text -> Text -> Bool -> ScriptMessage) -> StatementHandler g m
aiAttitude msg stmt@[pdx| %_ = @scr |] =
    let
        (mlocked, rest) = extractStmt (matchLhsText "locked") scr
        isLocked = (maybe "" T.toLower (getMaybeRhsText mlocked)) == "yes"
    in
        msgToPP =<< pp_aia isLocked (parseTA "who" "attitude" rest)
    where
        pp_aia :: Bool -> TextAtom -> PPT g m ScriptMessage
        pp_aia isLocked ta = case (ta_what ta, ta_atom ta) of
            (Just who, Just attitude) -> do
                let tags = T.splitOn ":" who -- A bit of a hack
                    icon = (iconText attitude) 
                attLoc <- getGameL10n attitude
                if length tags == 2 then do
                    taggedLoc <- tagged (tags !! 0) (tags !! 1)
                    return $ msg icon attLoc (fromMaybe who taggedLoc) isLocked
                else do
                    whoLoc <- flagText (Just EU4Country) who
                    return $ msg icon attLoc whoLoc isLocked
            _ -> return $ preMessage stmt
aiAttitude _ stmt = (trace $ "Not handled in aiAttitude: " ++ show stmt) $ preStatement stmt

------------------------------------------------------
-- Handler for {give,take}_estate_land_share_<size> --
------------------------------------------------------
estateLandShareEffect :: forall g m. (EU4Info g, Monad m) => Double -> StatementHandler g m
estateLandShareEffect amt stmt@[pdx| %_ = @scr |] | [pdx| estate = ?estate |] : [] <- scr =
    case T.toLower estate of
        "all" -> msgToPP $ MsgEstateLandShareEffectAll amt
        _ -> do
                eLoc <- getGameL10n estate
                msgToPP $ MsgEstateLandShareEffect amt (iconText estate) eLoc
estateLandShareEffect _ stmt = preStatement stmt

------------------------------------------
-- Handler for change_estate_land_share --
------------------------------------------
changeEstateLandShare :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
changeEstateLandShare stmt@[pdx| %_ = @scr |]
    = msgToPP =<< pp_cels (parseTV "estate" "share" scr)
    where
        pp_cels :: TextValue -> PPT g m ScriptMessage
        pp_cels tv = case (tv_what tv, tv_value tv) of
            (Just estate, Just share) ->
                case T.toLower estate of
                    "all" -> return $ MsgEstateLandShareEffectAll share
                    _ -> do
                        eLoc <- getGameL10n estate
                        return $ MsgEstateLandShareEffect share (iconText estate) eLoc
            _ -> return $ preMessage stmt
changeEstateLandShare stmt = preStatement stmt

--------------------------------------------------
-- Handler for {area,region}_for_scope_province --
--------------------------------------------------
scopeProvince :: forall g m. (EU4Info g, Monad m) => ScriptMessage -> ScriptMessage -> StatementHandler g m
scopeProvince msgAny msgAll stmt@[pdx| %_ = @scr |] =
    let
        (mtype, rest) = extractStmt (matchLhsText "type") scr
    in
        case mtype of
            Just typstm@[pdx| $_ = $typ |] -> withCurrentIndent $ \i -> do
                scr_pp'd <- ppMany rest
                let msg = case T.toLower typ of
                        "all" -> msgAll
                        "any" -> msgAny
                        _ -> (trace $ "scopeProvince: Unknown type " ++ (show typstm)) $ msgAll
                return ((i, msg) : scr_pp'd)
            _ -> compoundMessage msgAny stmt
scopeProvince _ _ stmt = preStatement stmt


---------------------------------------
-- Handler for *personality_ancestor --
---------------------------------------
personalityAncestor :: forall g m. (EU4Info g, Monad m) => (Text -> Text -> ScriptMessage) -> StatementHandler g m
personalityAncestor msg stmt@[pdx| %_ = @scr |] | [pdx| key = $personality |] : [] <- scr = do
    let perso = personality <> "_personality"
    loc <- getGameL10n perso
    msgToPP $ msg (iconText perso) loc
personalityAncestor _ stmt = preStatement stmt


-- Helper
getMaybeRhsText :: Maybe GenericStatement -> Maybe Text
getMaybeRhsText (Just [pdx| %_ = $t |]) = Just t
getMaybeRhsText _ = Nothing

-----------------------------------
-- Handler for has_great_project --
-----------------------------------
hasGreatProject :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
hasGreatProject stmt@[pdx| %_ = @scr |] =
    let
        (mtype, rest) = extractStmt (matchLhsText "type") scr
        (mtier, rest') = extractStmt (matchLhsText "tier") rest
        typ = fromMaybe "" (getMaybeRhsText mtype)
        (msgNoTier, msgTier) = case T.toLower typ of
            "any" -> (const MsgHasAnyGreatProject, const MsgHasAnyGreatProjectTier)
            "monument" -> (const MsgHasAnyMonument, const MsgHasAnyMonumentTier)
            _ -> (MsgHasGreatProject, MsgHasGreatProjectTier)
    in
        case (mtype, mtier, rest') of
            (Just s, Just [pdx| $_ = !tier |], []) -> do
                loc <- getGameL10n typ
                msgToPP $ msgTier loc tier
            (Just s, Nothing, []) -> do
                loc <- getGameL10n typ
                msgToPP $ msgNoTier loc
            _ -> (trace $ "hasGreatProject: Not handled: " ++ (show stmt)) $ preStatement stmt
hasGreatProject [pdx| %_ = $what |] = do -- Pre 1.31 great project
    whatLoc <- getGameL10n what
    msgToPP $ MsgConstructingGreatProject whatLoc
hasGreatProject stmt = (trace $ "hasGreatProject: Not handled: " ++ show stmt) $ preStatement stmt

----------------------------------------
-- Handler for has_estate_led_regency --
----------------------------------------
hasEstateLedRegency stmt@[pdx| %_ = @scr |] = do
    let (mestate, rest) = extractStmt (matchLhsText "estate") scr
        estate = fromMaybe "" (getMaybeRhsText mestate)
        icon = iconText estate
    loc <- getGameL10n estate
    case (T.toLower estate, rest) of
        ("", _) -> (trace $ ("hasEstateLedRegency: Estate missing: " ++ (show stmt))) $ msgToPP $ preMessage stmt
        ("any", [[pdx| duration = !dur |]]) -> msgToPP $ MsgEstateRegencyDuration dur
        ("any", [])                         -> msgToPP $ MsgEstateRegency
        (e, [[pdx| duration = !dur |]])     -> msgToPP $ MsgEstateRegencySpecificDur icon loc dur
        (e, [])                             -> msgToPP $ MsgEstateRegencySpecific icon loc
        _ -> (trace $ ("hasEstateLedRegency: Not handled: " ++ (show stmt))) $ msgToPP $ preMessage stmt
hasEstateLedRegency stmt = preStatement stmt

------------------------------
-- Handler for change_price --
------------------------------

data ChangePrice = ChangePrice
        { cp_tradegood  :: Maybe Text
        , cp_key :: Maybe Text
        , cp_value :: Maybe Double
        , cp_duration :: Maybe Double
        } deriving Show

newCP :: ChangePrice
newCP = ChangePrice Nothing Nothing Nothing Nothing

changePrice :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
changePrice stmt@[pdx| %_ = @scr |] = msgToPP =<< pp_cp (foldl' addLine newCP scr)
    where
        addLine :: ChangePrice -> GenericStatement -> ChangePrice
        addLine cp [pdx| trade_goods = $what |] = cp { cp_tradegood = Just what }
        addLine cp [pdx| key = $what |] = cp { cp_key = Just what }
        addLine cp [pdx| value = !val |] = cp { cp_value = Just val }
        addLine cp [pdx| duration = !val |] = cp { cp_duration = Just val }
        addLine ev stmt = (trace $ "Unknown in change_price " ++ show stmt) $ ev
        pp_cp :: ChangePrice -> PPT g m ScriptMessage
        pp_cp ChangePrice { cp_tradegood = Just tradegood, cp_key = Just key, cp_value = Just value, cp_duration = Just duration } = do
            tgLoc <- getGameL10n tradegood
            keyLoc <- getGameL10n key
            return $ MsgChangePrice (iconText tradegood) tgLoc keyLoc value duration
        pp_cp cp = return $ (trace $ "Missing info for change_price " ++ show cp ++ " " ++ (show stmt)) $ preMessage stmt
changePrice stmt = (trace $ "changePrice: Not handled: " ++ (show stmt)) $ preStatement stmt

---------------------------------
-- Handler for has_leader_with --
---------------------------------
data HasLeaderWith = HasLeaderWith
        { hlw_admiral :: Bool
        , hlw_general :: Bool
        , hlw_monarch :: Bool
        , hlw_total_pips :: Maybe Double
        , hlw_shock :: Maybe Double
        , hlw_fire :: Maybe Double
        , hlw_manuever :: Maybe Double
        , hlw_siege :: Maybe Double
        } deriving Show

newHLW :: HasLeaderWith
newHLW = HasLeaderWith False False False Nothing Nothing Nothing Nothing Nothing

hasLeaderWith :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
hasLeaderWith stmt@[pdx| %_ = @scr |] = pp_hlw (foldl' addLine newHLW scr)
    where
        addLine :: HasLeaderWith -> GenericStatement -> HasLeaderWith
        addLine hlw [pdx| general = $t |] | T.toLower t == "yes" = hlw { hlw_general = True }
        addLine hlw [pdx| admiral = $t |] | T.toLower t == "yes" = hlw { hlw_admiral = True }
        addLine hlw [pdx| is_monarch_leader = $t |] | T.toLower t == "yes" = hlw { hlw_monarch = True }
        addLine hlw [pdx| total_pips = %rhs |] = hlw { hlw_total_pips = floatRhs rhs }
        addLine hlw [pdx| shock = %rhs |] = hlw { hlw_shock = floatRhs rhs }
        addLine hlw [pdx| fire = %rhs |] = hlw { hlw_fire = floatRhs rhs }
        addLine hlw [pdx| manuever = %rhs |] = hlw { hlw_manuever = floatRhs rhs }
        addLine hlw [pdx| siege = %rhs |] = hlw { hlw_siege = floatRhs rhs }
        addLine hlw stmt = (trace $ "Unknown in has_leader_with: " ++ show stmt) $ hlw

        pp_hlw_attrib :: HasLeaderWith -> PPT g m (Maybe (IndentedMessage, HasLeaderWith))
        pp_hlw_attrib hlw@HasLeaderWith { hlw_total_pips = Just pips } = do
            [msg] <- msgToPP $ MsgTotalPips pips
            return (Just (msg, hlw { hlw_total_pips = Nothing }))
        pp_hlw_attrib _ = return Nothing

        pp_hlw :: HasLeaderWith -> PPT g m IndentedMessages
        pp_hlw hlw = do
            let ml = newML { ml_shock    = hlw_shock    hlw
                           , ml_fire     = hlw_fire     hlw
                           , ml_manuever = hlw_manuever hlw
                           , ml_siege    = hlw_siege    hlw }
                msg = case hlw of
                    HasLeaderWith { hlw_monarch = True } -> MsgHasMonarchLeaderWith
                    HasLeaderWith { hlw_admiral = True } -> MsgHasAdmiralWith (iconText "admiral")
                    HasLeaderWith { hlw_general = True } -> MsgHasGeneralWith (iconText "general")
                    _ -> MsgHasLeaderWith
            body1 <- indentUp (unfoldM pp_hlw_attrib hlw)
            body2 <- indentUp (unfoldM (pp_mil_leader_attrib (hlw_admiral hlw)) ml)
            liftA2 (++) (msgToPP msg) (pure (body1 ++ body2))

hasLeaderWith stmt = (trace $ "Not handled in has_leader_with: " ++ (show stmt)) $ preStatement stmt

-------------------------------------------------
-- Handler for kill_advisor_by_category_effect --
-------------------------------------------------

killAdvisorByCategory :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
killAdvisorByCategory stmt@[pdx| %_ = @scr |] | [[pdx| $typ = yes |]] <- scr = do
    typeLoc <- getGameL10n typ
    msgToPP $ MsgRemoveAdvisor typeLoc
killAdvisorByCategory stmt = (trace $ "Not handled in kill_advisor_by_category_effect: " ++ show stmt) $ preStatement stmt

------------------------
-- Handler for region --
------------------------
--
-- Can either be a compund statement or a normal condition
region :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
region stmt@[pdx| %_ = $_ |] = withLocAtom MsgRegionIs stmt
region stmt@[pdx| %_ = @_ |] = (scope EU4Province  . compoundMessage MsgRegion) stmt
region stmt = preStatement stmt

----------------------------------------
-- Handler for e.g. enlightenment = X --
----------------------------------------
institutionPresence :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
institutionPresence [pdx| $inst = !val |] = do
    instLoc <- getGameL10n inst
    msgToPP $ MsgInstitutionPresence (iconText inst) instLoc val
institutionPresence stmt = (trace $ "Warning: institutionPresence doesn't handle: " ++ (show stmt)) $ preStatement stmt

-----------------------------------
-- Handler for expulsion_target  --
-----------------------------------

expulsionTarget :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
expulsionTarget stmt@[pdx| %_ = @scr |] | [[pdx| province_id = $what |]] <- scr = do -- Not seen used with actual province id yet
    whatLoc <- Doc.doc2text <$> pronoun (Just EU4Province) what
    msgToPP $ MsgExpulsionTarget whatLoc
expulsionTarget stmt = (trace $ "Not handled in expulsion_target : " ++ show stmt) $ preStatement stmt

---------------------------------------------------
-- Handler for spawn_{small,large}_scaled_rebels --
---------------------------------------------------

-- Comments from common/scripted_effects/00_scripted_effects.txt
-- always specify type
-- specify saved_name = <saved_name> if you want to use one of those
-- specify leader and leader_dynasty if you want to do it that way <-- Not currently used
-- otherwise state "no_defined_leader = yes"

data SpawnScaledRebels = SpawnScaledRebels
    { ssr_type :: Maybe Text
    , ssr_saved_name :: Maybe Text
    } deriving Show

spawnScaledRebels :: forall g m. (EU4Info g, Monad m) => Bool -> StatementHandler g m
spawnScaledRebels large stmt@[pdx| %_ = @scr |] = msgToPP =<< pp_ssr (foldl' addLine (SpawnScaledRebels Nothing Nothing) scr)
    where
        addLine :: SpawnScaledRebels -> GenericStatement -> SpawnScaledRebels
        addLine ssr [pdx| type = $typ |] = ssr { ssr_type = Just typ }
        addLine ssr [pdx| no_defined_leader = yes |] = ssr -- ignored (should have saved_name instead)
        addLine ssr [pdx| saved_name = %name |] = ssr { ssr_saved_name = textRhs name }
        addLine ssr stmt = (trace $ "Not handled in spawnScaledRebels: " ++ show stmt) $ ssr
        pp_ssr :: SpawnScaledRebels -> PPT g m ScriptMessage
        pp_ssr ssr = do
            let rtype_loc_icon = flip HM.lookup rebel_loc =<< ssr_type ssr
            leaderText <- case ssr_saved_name ssr of
                Just leader -> do
                    mtext <- messageText (MsgRebelsLedBy ("saved name <tt>" <> leader <> "</tt>"))
                    return (" (" <> mtext <> ")")
                Nothing -> return ""
            return $ MsgSpawnScaledRebels
                (maybe "" (\(ty, ty_icon) -> iconText ty_icon <> " " <> ty) rtype_loc_icon)
                leaderText
                large
spawnScaledRebels _ stmt = (trace $ "Not handled in spawnScaledRebels: " ++ show stmt) $ preStatement stmt

data CreateIndependentEstate = CreateIndependentEstate
    {   cie_estate :: Maybe Text
    ,   cie_government :: Maybe Text
    ,   cie_government_reform :: Maybe Text
    ,   cie_national_ideas :: Maybe Text
    ,   cie_play_as :: Bool
    } deriving Show

createIndependentEstate :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
createIndependentEstate stmt@[pdx| %_ = @scr |] = msgToPP =<< pp_cie (foldl' addLine (CreateIndependentEstate Nothing Nothing Nothing Nothing False) scr)
    where
        addLine :: CreateIndependentEstate -> GenericStatement -> CreateIndependentEstate
        addLine cie [pdx| estate = $estate |] = cie { cie_estate = Just estate }
        addLine cie [pdx| government = $gov |] = cie { cie_government = Just gov }
        addLine cie [pdx| government_reform = $govreform |] = cie { cie_government_reform = Just govreform }
        addLine cie [pdx| custom_national_ideas = $ideas |] = cie { cie_national_ideas = Just ideas }
        addLine cie [pdx| play_as = $yn |] = cie { cie_play_as = T.toLower yn == "yes" }
        addLine cie stmt = (trace $ "Not handled in createIndependentEstate: " ++ show stmt) $ cie

        pp_cie :: CreateIndependentEstate -> PPT g m ScriptMessage
        pp_cie cie@CreateIndependentEstate{cie_estate = Just estate, cie_government = Just gov, cie_government_reform = Just reform, cie_national_ideas = Just ideas} = do
            estateLoc <- getGameL10n estate
            govLoc <- getGameL10n gov
            govReformLoc <- getGameL10n reform
            ideasLoc <- getGameL10n ideas
            -- FIXME: Should actually be localizable
            let desc = " with " <> govLoc <> " government, the " <> govReformLoc <> " reform and " <> ideasLoc
            return $ MsgCreateIndependentEstate (iconText estate) estateLoc desc (cie_play_as cie)
        pp_cie cie@CreateIndependentEstate{cie_estate = Just estate, cie_government = Nothing, cie_government_reform = Nothing, cie_national_ideas = Nothing} = do
            estateLoc <- getGameL10n estate
            return $ MsgCreateIndependentEstate (iconText estate) estateLoc "" (cie_play_as cie)
        pp_cie cie = return $ (trace $ "Not handled in createIndependentEstate: cie=" ++ show cie ++ " stmt=" ++ show stmt) $ preMessage stmt
createIndependentEstate stmt = (trace $ "Not handled in createIndependentEstate: " ++ show stmt) $ preStatement stmt

-----------------------------------------
-- Helper for has_xxx_building_trigger --
-----------------------------------------
hasBuildingTrigger :: forall g m. (EU4Info g, Monad m) => [Text] -> StatementHandler g m
hasBuildingTrigger buildings stmt@[pdx| %_ = $yn |] = do
    locAndIcons <- mapM locAndIcon buildings
    let buildingText = fmtList locAndIcons
    case T.toLower yn of
        "yes" -> msgToPP $ MsgHasOneOfBuildings True buildingText
        "no" -> msgToPP $ MsgHasOneOfBuildings False buildingText
        _ -> (trace $ "Not handled in hasBuildingTrigger: " ++ show stmt) $ preStatement stmt
        where
            locAndIcon b = do
                loc <- getGameL10n $ "building_" <> b
                return (iconText b, loc)
            fmtList [] = ""
            fmtList ((i,b):bs) = i <> " " <> b <> (case length bs of
                0 -> ""
                1 -> " or "
                _ -> ", ") <> fmtList bs
hasBuildingTrigger _ stmt = (trace $ "Not handled in hasBuildingTrigger: " ++ show stmt) $ preStatement stmt

-----------------------------------
-- Handler for production_leader --
-----------------------------------
foldCompound "productionLeader" "ProductionLeader" "pl"
    []
    [CompField "trade_goods" [t|Text|] Nothing True
    ,CompField "value" [t|Text|] Nothing False
    ]
    [| do
        -- The "value = yes" part doesn't seem to do anything that appears in Aragon's mission tree doesn't appear
        -- to do anything. It's probably a copy/paste error from a trading_bonus clause.
        tgLoc <- getGameL10n _trade_goods
        return $ MsgIsProductionLeader (iconText _trade_goods) tgLoc
    |]

-------------------------------------------------
-- Handler for add_province_triggered_modifier --
-------------------------------------------------
addProvinceTriggeredModifier :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
addProvinceTriggeredModifier stmt@[pdx| %_ = $id |] = do
    mmod <- HM.lookup id <$> getProvinceTriggeredModifiers
    case mmod of
        Just mod -> withCurrentIndent $ \i -> do
            effect <- scope EU4Bonus $ ppMany (ptmodEffects mod)
            trigger <- indentUp $ scope EU4Province $ ppMany (ptmodTrigger mod)
            let name = ptmodLocName mod
                locName = maybe ("<tt>" <> id <> "</tt>") (Doc.doc2text . iquotes) name
            return $ ((i, MsgAddProvinceTriggeredModifier locName) : effect) ++ (if null trigger then [] else ((i+1, MsgLimit) : trigger))
        _ -> (trace $ "add_province_triggered_modifier: Modifier " ++ T.unpack id ++ " not found") $ preStatement stmt
addProvinceTriggeredModifier stmt = (trace $ "Not handled in addProvinceTriggeredModifier: " ++ show stmt) $ preStatement stmt

--------------------------
-- Handler for has_heir --
--------------------------
hasHeir :: forall g m. (EU4Info g, Monad m) => StatementHandler g m
hasHeir stmt@[pdx| %_ = ?rhs |] = msgToPP $
    case T.toLower rhs of
        "yes" -> MsgHasHeir True
        "no" -> MsgHasHeir False
        _ -> MsgHasHeirNamed rhs
hasHeir stmt = (trace $ "Not handled in hasHeir " ++ show stmt) $ preStatement stmt

---------------------------
-- Handler for kill_heir --
---------------------------
killHeir :: (EU4Info g, Monad m) => StatementHandler g m
killHeir stmt@(Statement _ OpEq (CompoundRhs [])) = msgToPP $ MsgHeirDies True
killHeir stmt@(Statement _ OpEq (CompoundRhs [Statement (GenericLhs "allow_new_heir" []) OpEq (GenericRhs "no" [])])) = msgToPP $ MsgHeirDies False
killHeir stmt = (trace $ "Not handled in killHeir: " ++ show stmt) $ preStatement stmt


----------------------------------------------
-- Handler for create_colony_mission_reward --
----------------------------------------------
createColonyMissionReward :: (EU4Info g, Monad m) => StatementHandler g m
createColonyMissionReward stmt =
    case getEffectArg "province" stmt of
        Just (IntRhs num) -> do
            prov <- getProvLoc num
            msgToPP $ MsgColonyMissionReward prov
        _ -> (trace $ "warning: Not handled by createColonyMissionReward: " ++ (show stmt)) $ preStatement stmt

--------------------------------
-- Handler for has_idea_group --
--------------------------------
hasIdeaGroup :: (EU4Info g, Monad m) => StatementHandler g m
hasIdeaGroup stmt@[pdx| %_ = ?ig |] =
    -- TODO: Improve
    -- Dirty check, if of the form XXX_ideas (where XXX are upper caes letters) assume national ideas..
    if  ((T.length ig) > 4) && ((T.index ig 3) == '_') && (isUpper (T.index ig 0)) && (isUpper (T.index ig 1)) && (isUpper (T.index ig 2)) then do
        countryLoc <- getGameL10n (T.take 3 ig)
        textLoc <- getGameL10n ig
        -- Show flag (again, dirty)
        msgToPP $ MsgHasIdeaGroup ("[[File:" <> countryLoc <> ".png|20px]]") textLoc
    else do -- "normal" idea group or group national idea
        igs <- getIdeaGroups
        textLoc <- getGameL10n ig
        if maybe False ig_free (HM.lookup ig igs) then
            msgToPP $ MsgHasIdeaGroup "" textLoc -- group national idea -> no icon
        else
            msgToPP $ MsgHasIdeaGroup (iconText ig) textLoc
hasIdeaGroup stmt = (trace $ "Not handled in hasIdeaGroup: " ++ show stmt) $ preStatement stmt

----------------------------
-- Handler for kill_units --
----------------------------
foldCompound "killUnits" "KillUnits" "ku"
    []
    [CompField "amount" [t|Double|] Nothing True
    ,CompField "type" [t|Text|] Nothing True
    ,CompField "who" [t|Text|] Nothing True]
    [| do
        who <- flagText (Just EU4Country) _who
        what <- getGameL10n _type
        return $ MsgKillUnits (iconText what) what who _amount
    |]

-------------------------------------------
-- Handler for add_building_construction --
-------------------------------------------
foldCompound "addBuildingConstruction" "BuildingConstruction" "bc"
    []
    [CompField "building" [t|Text|] Nothing True
    ,CompField "speed" [t|Double|] Nothing True
    ,CompField "cost" [t|Double|] Nothing True]
    [| do
        buildingLoc <- getGameL10n ("building_" <> _building)
        return $ MsgConstructBuilding (iconText _building) buildingLoc _speed _cost
    |]

----------------------------------------------------
-- Handler for has_reached_government_reform_tier --
----------------------------------------------------
hasGovernmentReforTier :: (EU4Info g, Monad m) => StatementHandler g m
hasGovernmentReforTier stmt@(Statement _ OpEq (CompoundRhs [Statement (GenericLhs tier []) OpEq (GenericRhs "yes" [])])) | T.isPrefixOf "tier_" tier =
    msgToPP $ MsgHasReformTier $ (read (T.unpack $ T.drop 5 tier) :: Double)
hasGovernmentReforTier stmt = (trace $ "Not handled in hasGovernmentReforTier: " ++ show stmt) $ preStatement stmt
