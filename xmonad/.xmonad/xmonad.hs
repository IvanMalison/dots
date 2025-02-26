-- Base
import           Control.Monad
import           Data.IORef
import           System.Directory
import           System.Exit                    ( exitSuccess )
import           System.IO                      ( hPutStrLn )
import           XMonad
import qualified XMonad.StackSet               as W

-- Actions
import           XMonad.Actions.CopyWindow      ( kill1 )
import           XMonad.Actions.CycleWS         ( Direction1D(..)
                                                , WSType(..)
                                                , moveTo
                                                , nextScreen
                                                , prevScreen
                                                , shiftTo
                                                , toggleWS
                                                )
import           XMonad.Actions.GroupNavigation
import           XMonad.Actions.PerWorkspaceKeys
import           XMonad.Actions.Promote
import           XMonad.Actions.WithAll         ( killAll
                                                , sinkAll
                                                )

-- Data
import           Data.Char                      ( isSpace
                                                , toUpper
                                                )
import qualified Data.Map                      as M
import           Data.Maybe
import           Data.Monoid
import           Data.Tree

-- Hooks
import           XMonad.Hooks.DynamicLog        ( PP(..)
                                                , dynamicLogWithPP
                                                , shorten
                                                , wrap
                                                , xmobarColor
                                                , xmobarPP
                                                )
import           XMonad.Hooks.DynamicProperty
import           XMonad.Hooks.EwmhDesktops
import           XMonad.Hooks.ManageDocks       ( ToggleStruts(..)
                                                , avoidStruts
                                                , docksEventHook
                                                , manageDocks
                                                )
import           XMonad.Hooks.ManageHelpers     ( doFullFloat
                                                , isFullscreen
                                                )
import           XMonad.Hooks.SetWMName
import           XMonad.Hooks.WorkspaceHistory

-- Layouts
import           XMonad.Layout.LayoutModifier
import           XMonad.Layout.LimitWindows     ( decreaseLimit
                                                , increaseLimit
                                                , limitWindows
                                                )
import           XMonad.Layout.MultiToggle      ( (??)
                                                , EOT(EOT)
                                                , mkToggle
                                                , single
                                                )
import qualified XMonad.Layout.MultiToggle     as MT
                                                ( Toggle(..) )
import           XMonad.Layout.MultiToggle.Instances
                                                ( StdTransformers(MIRROR, NBFULL, NOBORDERS) )
import           XMonad.Layout.NoBorders
import           XMonad.Layout.Renamed
import           XMonad.Layout.ResizableTile
import           XMonad.Layout.Simplest
import           XMonad.Layout.Spacing
import           XMonad.Layout.SubLayouts
import qualified XMonad.Layout.ToggleLayouts   as T
                                                ( ToggleLayout(Toggle)
                                                , toggleLayouts
                                                )
import           XMonad.Layout.WindowArranger   ( WindowArrangerMsg(..)
                                                , windowArrange
                                                )
import           XMonad.Util.EZConfig           ( additionalKeys
                                                , additionalKeysP
                                                )
import           XMonad.Util.Run                ( runProcessWithInput
                                                , safeSpawn
                                                , spawnPipe
                                                )
import           XMonad.Util.SpawnOnce

myFont :: String
myFont = "xft:Jetbrains Mono Nerd Font Mono:regular:size=9:antialias=true:hinting=true"

myModMask :: KeyMask
myModMask = mod4Mask        -- Sets modkey to super/windows key

myTerminal :: String
myTerminal = "alacritty"

myLayout :: String
myLayout = "qwerty"

myBrowser :: String
myBrowser = "qutebrowser "

myEditor :: String
myEditor = myTerminal ++ " -e nvim "

myBorderWidth :: Dimension
myBorderWidth = 2

myNormColor :: String
myNormColor = "#2E3440"

myFocusColor :: String
myFocusColor = "#5E81AC"

windowCount :: X (Maybe String)
windowCount =
  gets $ Just . show . length . W.integrate' . W.stack . W.workspace . W.current . windowset

-- Launch Stuff on startup
myStartupHook :: X ()
myStartupHook = do
  spawnOnce "picom --experimental-backend -b&"
  spawnOnce "dunst"
  spawnOnce "$HOME/.xmonad/scripts/trayer.sh"
  --spawnOnce " hsetroot -solid '#2E3440'"
  spawnOnce "~/.fehbg"
  spawnOnce "xcape -f -t 150"
  spawnOnce "discord"
  spawnOnce "slack"
  spawnOnce "element-desktop"
  setWMName "LG3D"

-- mySpacing helps to set gaps
mySpacing :: Integer -> l a -> XMonad.Layout.LayoutModifier.ModifiedLayout Spacing l a
mySpacing i = spacingRaw False (Border i i i i) True (Border i i i i) True

tall =
  renamed [Replace "tall"]
    $ smartBorders
    $ subLayout [] (smartBorders Simplest)
    $ limitWindows 12
    $ mySpacing 2
    $ ResizableTall 1 (3 / 100) (1 / 2) []

-- Layout hook (Only tall for now)
myLayoutHook = smartBorders $ avoidStruts $ windowArrange $ mkToggle (NBFULL ?? NOBORDERS ?? EOT)
                                                                     myDefaultLayout
  where myDefaultLayout = withBorder myBorderWidth tall

-- Workspace names and indicied
myWorkspaces = ["dev", "web", "test", "mtrx", "dsc", "slck", "mus", "sch", "virt"]
myWorkspaceIndices = M.fromList $ zip myWorkspaces [1 ..]

-- Make workspaces clickable
clickable ws = "<action=xdotool key super+" ++ show i ++ ">" ++ ws ++ "</action>"
  where i = fromJust $ M.lookup ws myWorkspaceIndices

-- Shift windows to another workspace automatically
myManageHook :: XMonad.Query (Data.Monoid.Endo WindowSet)
myManageHook = composeAll
  [ className =? "confirm" --> doFloat
  , className =? "file_progress" --> doFloat
  , className =? "dialog" --> doFloat
  , className =? "download" --> doFloat
  , className =? "error" --> doFloat
  , className =? "Gimp" --> doFloat
  , className =? "notification" --> doFloat
  , className =? "pinentry-gtk-2" --> doFloat
  , className =? "splash" --> doFloat
  , className =? "toolbar" --> doFloat
  , className =? "virt-manager" --> doFloat
  , isFullscreen --> doFullFloat
  , className =? "Evince" --> doShift (myWorkspaces !! 3)
  , className =? "Element" --> doShift (myWorkspaces !! 3)
  , className =? "discord" --> doShift (myWorkspaces !! 4)
  , className =? "Slack" --> doShift (myWorkspaces !! 5)
  , className =? "Audacious" --> doShift (myWorkspaces !! 6)
  , className =? "zoom" --> doShift (myWorkspaces !! 7)
  , className =? "Virt-manager" --> doShift (myWorkspaces !! 8)
  , className =? "mpv" --> doFullFloat
  ]


-- Spotify is a weird case
myHandleEventHook = dynamicPropertyChange "WM_CLASS"
  $ composeAll [className =? "Spotify" --> doShift (myWorkspaces !! 5)]

combineActions :: IORef String -> M.Map String (X ()) -> X ()
combineActions ref layoutToAction = do
   currentLayout <- liftIO $ readIORef ref
   fromMaybe (return ()) $ M.lookup currentLayout layoutToAction


combineKeyMaps ::
  IORef String -> [(String, M.Map (KeyMask, KeySym) (X ()))] -> M.Map (KeyMask, KeySym) (X ())
combineKeyMaps ref theMaps = M.map (combineActions ref) combinedMaps
  where insertSymsInto layoutString accum keysym value =
          let newMap = M.insert layoutString value $ M.findWithDefault M.empty keysym accum
          in M.insert keysym newMap accum
        insertMapSymsInto
          :: M.Map (KeyMask, KeySym) (M.Map String (X ()))
          -> (String, M.Map (KeyMask, KeySym) (X ()))
          -> M.Map (KeyMask, KeySym) (M.Map String (X ()))
        insertMapSymsInto accum (layoutString, layoutMap) =
          M.foldlWithKey (insertSymsInto layoutString) accum layoutMap
        combinedMaps = foldl insertMapSymsInto M.empty theMaps


useDvorak :: IORef String -> X ()
useDvorak ref = liftIO $ writeIORef ref "dvorak"

useQwerty :: IORef String -> X ()
useQwerty ref = liftIO $ writeIORef ref "qwerty"

-- Main keybinds
myKeys :: [(String, X ())]
myKeys =
  [
        -- XMonad stuff
    ("M-M1-c"                , spawn "xmonad --recompile")  -- Recompiles xmonad
  , ("M-M1-r"                , spawn "xmonad --restart")    -- Restarts xmonad
  , ("M-M1-e"                , io exitSuccess)              -- Quits xmonad
  , ("M-S-l", spawn "$HOME/.xmonad/scripts/switchlayout.sh")
  , ("M-S-<Return>"          , spawn "dmenu_run -p 'Run:' -h 24") -- Dmenu

        -- Dmenu stuff
  , ("M-p e"                 , spawn "dmconf")   -- edit config files
  , ("M-p k"                 , spawn "dmkill")   -- kill processes
  , ("M-p q"                 , spawn "dmlogout") -- logout menu
  , ("M-p s"                 , spawn "dmsearch") -- search various search engines

        -- Launch keybinds
  , ("M-<Return>", spawn "$HOME/.xmonad/scripts/terminal.sh")
  , ("M-\\"                  , spawn myTerminal)
  , ("M-i"                   , spawn myBrowser)
  , ("M-b"                   , spawn "brave")
  , ("M-S-h"                 , spawn (myTerminal ++ " -e htop"))
  , ("M-S-x"                 , spawn "loginctl suspend")
  , ("M-a"                   , spawn "xset r rate 300 50")
  , ("M-c", spawn "colorpicker --short --one-shot --preview | xclip -selection clipboard")

        -- Kill windows
  , ("M-q"                   , kill1)     -- Kill the currently focused client
  , ("M-S-q"                 , killAll)   -- Kill all windows on current workspace
  , ("M-u"                   , nextMatch History (return True))-- Move to recent workspace

        -- Increase/decrease gaps
  , ("C-M1-j"                , decWindowSpacing 4)         -- Decrease window spacing
  , ("C-M1-k"                , incWindowSpacing 4)         -- Increase window spacing
  , ("C-M1-h"                , decScreenSpacing 4)         -- Decrease screen spacing
  , ("C-M1-l"                , incScreenSpacing 4)         -- Increase screen spacing

        -- Window navigation
  , ("M-j"                   , windows W.focusDown)    -- Move focus to the next window
  , ("M-k"                   , windows W.focusUp)      -- Move focus to the prev window
  , ("M-<Backspace>"         , promote)      -- Moves focused window to master, others maintain order

        -- Fullscreen
  , ("M-<Space>", sendMessage (MT.Toggle NBFULL) >> sendMessage ToggleStruts) -- Toggles noborder/full

        -- Window resizing
  , ("M-h"                   , sendMessage Shrink)                   -- Shrink horiz window width
  , ("M-l"                   , sendMessage Expand)                   -- Expand horiz window width
  , ("M-M1-j"                , sendMessage MirrorShrink)          -- Shrink vert window width
  , ("M-M1-k"                , sendMessage MirrorExpand)          -- Expand vert window width

        -- Multimedia Keys
  , ("<XF86AudioPlay>"       , spawn "playerctl play-pause")
  , ("M-s p"                 , spawn "playerctl play-pause")
  , ("<XF86AudioPrev>"       , spawn "playerctl previous")
  , ("M-s b"                 , spawn "playerctl previous")
  , ("<XF86AudioNext>"       , spawn "playerctl next")
  , ("M-s n"                 , spawn "playerctl next")
  , ("<XF86AudioMute>", spawn "pactl set-sink-mute 0 toggle")
  , ("<XF86AudioLowerVolume>", spawn "pactl -- set-sink-volume 0 -5%")
  , ("<XF86AudioRaiseVolume>", spawn "pactl -- set-sink-volume 0 +5%")
  , ("<XF86Calculator>"      , spawn "qalculate-gtk")
  , ("<Print>", spawn "maim -su | xclip -selection clipboard -t image/png")
  , ( "C-<Print>"
    , spawn "maim -u -i $(xdotool getactivewindow) | xclip -selection clipboard -t image/png"
    )
  , ("C-S-<Print>", spawn "maim -u | xclip -selection clipboard -t image/png")
  ]

-- QWERTY and Programmer Dvorak stuff

-- Go to a specific workspace
workspaceBinds layout | layout == "qwerty" = qwerty
                      | layout == "dvorak" = dvorak
                      | otherwise          = qwerty
 where
  qwerty =
    [ ((myModMask, k), bindOn [("", windows $ W.greedyView n), (n, toggleWS)])
    | (n, k) <- zip myWorkspaces ([xK_1 .. xK_9] ++ [xK_0])
    ]
  dvorak =
    [ ((myModMask, k), bindOn [("", windows $ W.greedyView n), (n, toggleWS)])
    | (n, k) <- zip
      myWorkspaces
      ([ xK_ampersand
       , xK_bracketleft
       , xK_braceleft
       , xK_braceright
       , xK_parenleft
       , xK_equal
       , xK_asterisk
       , xK_parenright
       , xK_plus
       , xK_bracketright
       ]
      )
    ]

-- Shift workspaces to another workspace
workspaceShiftBinds layout | layout == "qwerty" = qwertyShift
                           | layout == "dvorak" = dvorakShift
                           | otherwise          = qwertyShift
 where
  dvorakShift conf@(XConfig { XMonad.modMask = modm }) =
    M.fromList
      $ [ ((m .|. modm, k), windows $ f i)
        | (i, k) <- zip
          (XMonad.workspaces conf)
          [ xK_ampersand
          , xK_bracketleft
          , xK_braceleft
          , xK_braceright
          , xK_parenleft
          , xK_equal
          , xK_asterisk
          , xK_parenright
          , xK_plus
          , xK_bracketright
          ]
        , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
        ]

  qwertyShift conf@(XConfig { XMonad.modMask = modm }) =
    M.fromList
      $ [ ((m .|. modm, k), windows $ f i)
        | (i, k) <- zip (XMonad.workspaces conf) [xK_1 .. xK_9]
        , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]
        ]

-- XMonad defaults
defaults ref xmproc0 =
  def
      { manageHook         = myManageHook <+> manageDocks
      , handleEventHook    = docksEventHook <+> fullscreenEventHook <+> myHandleEventHook
      , modMask            = myModMask
      , terminal           = myTerminal
      , startupHook        = myStartupHook
      , layoutHook         = myLayoutHook
      , workspaces         = myWorkspaces
      , keys               = workspaceShiftBinds myLayout
      , borderWidth        = myBorderWidth
      , normalBorderColor  = myNormColor
      , focusedBorderColor = myFocusColor
      , logHook            = dynamicLogWithPP xmobarPP
                                 { ppOutput          = hPutStrLn xmproc0
                                 , ppCurrent = xmobarColor "#A3BE8C" "" . wrap "[" "]" . clickable
                                 , ppVisible         = xmobarColor "#A3BE8C" "" . clickable
                                 , ppHidden = xmobarColor "#81A1C1" "" . wrap "*" "" . clickable
                                 , ppHiddenNoWindows = xmobarColor "#B48EAD" "" . clickable
                                 , ppTitle           = xmobarColor "#D8DEE9" "" . shorten 100
                                 , ppSep             = "<fc=#4C566A> <fn=1>|</fn> </fc>"
                                 , ppUrgent          = xmobarColor "#BF616A" "" . wrap "!" "!"
                                 , ppExtras          = [windowCount]
                                 , ppOrder           = \(ws : l : t : ex) -> [ws, l] ++ ex ++ [t]
                                 }
                               >> historyHook
      }
    `additionalKeys` (M.toList $ combineKeyMaps ref
       [ ("qwerty", M.fromList $ workspaceBinds "qwerty")
       , ("dvorak", M.fromList $ workspaceBinds "dvorak")
       ])
    `additionalKeysP` myKeys

-- Main function
main :: IO ()
main = do
  ref <- newIORef "qwerty"
  xmproc0 <- spawnPipe "$HOME/.config/xmobar/xmobar"
  xmonad $ ewmh $ defaults ref xmproc0
