{-# language BlockArguments #-}
{-# language LambdaCase #-}
{-# language OverloadedStrings #-}
{-# language RecordWildCards #-}
{-# language NamedFieldPuns #-}
{-# language DeriveTraversable #-}

{- | Font usage example.

Loads two non-standard fonts

This example uses NotoSansJP-Regular.otf from Google Fonts
Licensed under the SIL Open Font License, Version 1.1
https://fonts.google.com/noto/specimen/Noto+Sans+JP
-}

module Main ( main ) where

import Control.Exception
import Control.Monad
import Control.Monad.IO.Class
import Control.Monad.Managed
import Data.IORef
import DearImGui
import qualified DearImGui.FontAtlas as FontAtlas
import DearImGui.OpenGL2
import DearImGui.SDL
import DearImGui.SDL.OpenGL
import Graphics.GL
import SDL

-- Rebuild syntax enables us to keep fonts in any
-- traversable type, so let's make our life a little easier.
-- But feel free to use lists or maps.
data FontSet a = FontSet
  { droidFont :: a
  , defaultFont :: a
  , notoFont :: a
  }
  deriving (Functor, Foldable, Traversable)

main :: IO ()
main = do
  -- Window initialization is similar to another examples.
  initializeAll
  runManaged do
    window <- do
      let title = "Hello, Dear ImGui!"
      let config = defaultWindow { windowGraphicsContext = OpenGLContext defaultOpenGL }
      managed $ bracket (createWindow title config) destroyWindow
    glContext <- managed $ bracket (glCreateContext window) glDeleteContext
    _ <- managed $ bracket createContext destroyContext
    _ <- managed_ $ bracket_ (sdl2InitForOpenGL window glContext) sdl2Shutdown
    _ <- managed_ $ bracket_ openGL2Init openGL2Shutdown

    -- We use high-level syntax to build font atlas and
    -- get handles to use in the main loop.
    fontSet <- FontAtlas.rebuild FontSet
      { -- The first mentioned font is loaded first
        -- and set as a global default.
        droidFont =
          FontAtlas.FromTTF
            "./imgui/misc/fonts/DroidSans.ttf"
            15
            Nothing
            FontAtlas.Cyrillic

        -- You also may use a default hardcoded font for
        -- some purposes (i.e. as fallback)
      , defaultFont =
          FontAtlas.DefaultFont

        -- To optimize atlas size, use ranges builder and
        -- provide source localization data.
      , notoFont =
          FontAtlas.FromTTF
            "./examples/fonts/NotoSansJP-Regular.otf"
            20
            Nothing
            ( FontAtlas.RangesBuilder $ mconcat
                [ FontAtlas.addRanges FontAtlas.Latin
                , FontAtlas.addText "私をクリックしてください"
                , FontAtlas.addText "こんにちは"
                ]
            )
      }

    liftIO $ do
      fontFlag <- newIORef False
      mainLoop window do
        let FontSet{..} = fontSet
        withWindowOpen "Hello, ImGui!" do
          -- To use a font for widget text, you may either put it
          -- into a 'withFont' block:
          withFont defaultFont do
            text "Hello, ImGui!"

          text "Привет, ImGui!"

          -- ...or you can explicitly push and pop a font.
          -- Though it's not recommended.
          toggled <- readIORef fontFlag

          when toggled $
            pushFont notoFont

          -- Some of those are only present in Noto font range
          -- and will render as `?`s.
          text "こんにちは, ImGui!"

          let buttonText = if toggled then "私をクリックしてください" else "Click Me!"
          button buttonText >>= \clicked ->
            when clicked $
              modifyIORef' fontFlag not

          when toggled
            popFont

        showDemoWindow

mainLoop :: Window -> IO () -> IO ()
mainLoop window frameAction = loop
  where
  loop = unlessQuit do
    openGL2NewFrame
    sdl2NewFrame
    newFrame

    frameAction

    glClear GL_COLOR_BUFFER_BIT
    render
    openGL2RenderDrawData =<< getDrawData
    glSwapWindow window

    loop

  unlessQuit action = do
    shouldQuit <- checkEvents
    if shouldQuit then pure () else action

  checkEvents = do
    pollEventWithImGui >>= \case
      Nothing ->
        return False
      Just event ->
        (isQuit event ||) <$> checkEvents

  isQuit event =
    SDL.eventPayload event == SDL.QuitEvent
