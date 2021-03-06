module Main exposing (..)

import Nav
import Cmd.Extra exposing (mkCmd)
import Session

import Window
import Navigation
import Duration
import Ease

import Task
import Time exposing (Time, millisecond)
import Color


import Html.App        as App
import Html            exposing (..)
import Html.Attributes exposing (..)
import Html.Events     exposing (..)




type ResponsiveScreen
  = Mobile
  | Tablet
  | Small
  | Large

isMobile : ResponsiveScreen -> Bool
isMobile s =
  case s of
    Mobile -> True
    Tablet -> True
    _      -> False


type alias Model =
  { nav             : Nav.Model
  , deviceWidth     : ResponsiveScreen
  , height          : Int
  , sidebarDuration : Duration.Model Msg
  , dimmer          : Float
  , session         : Session.Model Msg
  }

type Msg
  = NavMsg Nav.Msg
  | ChangeScreenWidth Int
  | ChangeScreenHeight Int
  | ChangeScreenSize Window.Size
  | DurationMsg (Duration.Msg Msg)
  | ChangeDimmer Float
  | SessionMsg (Session.Msg Msg)


-- type alias Flags =
--   { privateKey : 
--   }

init : (Model, Cmd Msg)
init =
  let (newNav, navEff) = Nav.init
      (newSession, sessionEff) = Session.init
  in  ( { nav             = newNav
        , deviceWidth     = Mobile
        , height          = 0
        , dimmer          = 0
        , sidebarDuration = Duration.init
        , session         = newSession
        }
      , Cmd.batch
          [ Cmd.map NavMsg navEff
          , Cmd.map SessionMsg sessionEff
          , Task.perform
              Debug.crash
              ChangeScreenSize
              Window.size
          ]
      )

update : Msg -> Model -> (Model, Cmd Msg)
update action model =
  case action of
    NavMsg a ->
      let (newNav, eff) = Nav.update a model.nav
      in  ( { model | nav = newNav }
          , Cmd.map NavMsg eff
          )
    SessionMsg a ->
      let (newSession, eff) = Session.update (\_ -> Cmd.none) a model.session
      in  ( { model | session = newSession }
          , Cmd.map (\r -> case r of
                             Err x -> SessionMsg x
                             Ok x  -> x) eff
          )
    DurationMsg a ->
      let timeLength = 500 * millisecond
          (newDur, eff) = Duration.update
                            (\t -> Cmd.batch
                                     [ mkCmd <| NavMsg <| Nav.ChangePosition <|
                                         Ease.outQuad <| t / timeLength
                                     , mkCmd <| NavMsg <| Nav.ChangeVisibility <|
                                         Ease.outQuad <| t / timeLength
                                     , mkCmd <| ChangeDimmer <|
                                         Ease.inCubic <| t / timeLength
                                     ]
                            )
                            timeLength
                            a
                            model.sidebarDuration
      in  ( { model | sidebarDuration = newDur }
          , Cmd.map (\r -> case r of
                             Err x -> x
                             Ok  x -> x) eff
          )
    ChangeScreenHeight h ->
      ( { model | height = h }
      , Cmd.none
      )
    ChangeScreenWidth w ->
      ( { model | deviceWidth =
            if w > 1200
            then Large
            else if w > 992
            then Small
            else if w > 768
            then Tablet
            else Mobile
        }
      , Cmd.none
      )
    ChangeScreenSize s ->
      ( model
      , Cmd.batch
          [ mkCmd <| ChangeScreenHeight s.height
          , mkCmd <| ChangeScreenWidth s.width
          ]
      )
    ChangeDimmer d ->
      ( { model | dimmer = d }
      , Cmd.none
      )

view : Model -> Html Msg
view model =
  let mobileSidebar = App.map NavMsg <| Nav.viewMobile model.nav
      mobileMenuButton =
        a [ class "item"
          , onClick <| DurationMsg <|
              case model.sidebarDuration.elapsed of
                Just _  -> Duration.Toggle <| \_ -> Cmd.none
                Nothing ->
                  if model.nav.position == 0
                  then Duration.Forward <| \_ -> Cmd.none
                  else Duration.Reverse <| \_ -> Cmd.none
          ]
          [i [class "icon sidebar"] []]
  in  div [] <|
        ( if isMobile model.deviceWidth
          then [mobileSidebar]
          else []
        ) ++
        [ div [ class "ui top fixed menu"
              , style <|
                  [ ( "border-bottom"
                    , let c' = Color.toHsl <| Color.rgb 238 130 238
                          l = c'.lightness - (model.dimmer * (c'.lightness - 0.2))
                          c = Color.toRgb <| Color.hsl c'.hue c'.saturation l
                      in "2px solid rgb(" ++ toString c.red ++ ","
                          ++ toString c.green ++ "," ++ toString c.blue ++ ")"
                    )
                  , ( "background"
                    , let bg = Color.toRgb <| Color.hsl 0 0 (1 - (0.5 * model.dimmer))
                      in  "rgb(" ++ toString bg.red ++ "," ++ toString bg.green
                          ++ "," ++ toString bg.blue ++ ")"
                    )
                  ] ++ if model.nav.visibility > 0
                       then [ ( "left"
                              , let length = 260
                                in  toString (negate <| length -
                                                (length * model.nav.position))
                                    ++ "px"
                              )
                            ]
                       else []
              ] <|
            let sessionButton =
                  div [class "right menu"]
                    [ App.map SessionMsg <|
                        Session.viewMenuItem model.session
                    ]
            in if isMobile model.deviceWidth
            then [ mobileMenuButton
                 , sessionButton
                 ]
            else List.map (App.map NavMsg) (Nav.view model.nav)
              ++ [ sessionButton
                 ]
        , div [ class "pusher"
              , style <|
                  if model.nav.visibility > 0
                  then [ ("position", "relative")
                       , ( "left"
                         , let length = 260
                           in  toString (negate <| length -
                                           (length * model.nav.position))
                               ++ "px"
                         )
                       ]
                  else []
              ]
            [ div [class "full height"] <|
                [ div [style [( "margin-top", "4em")]] []
                , div [ class <| "ui grid"
                          ++ if isMobile model.deviceWidth
                             then ""
                             else " container"
                      ]
                    [ div [ class "sixteen wide column"
                          , style <|
                              if isMobile model.deviceWidth
                              then [ ("margin-left", "1rem")
                                   , ("margin-right", "1rem")
                                   ]
                              else []
                          ]
                        [ div [class "ui segment"]
                            [ text "Foo"
                            ]
                        ]
                    ]
                ] ++ if isMobile model.deviceWidth
                     then [ div [ class <| "ui dimmer"
                                    ++ if model.nav.visibility > 0
                                       then " visible active"
                                       else " hidden"
                                , style [ ( "height"
                                          , toString model.height ++ "px"
                                          )
                                        , ( "opacity"
                                          , toString <| 0.8 * model.dimmer
                                          )
                                        ]
                                , onClick <| DurationMsg <|
                                    Duration.Reverse <| \_ -> Cmd.none
                                ] []
                          ]
                     else []
            ]
        -- modals
        ]

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.batch
    [ Window.resizes ChangeScreenSize
    , Sub.map DurationMsg <| Duration.subscriptions model.sidebarDuration
    , Sub.map SessionMsg <| Session.subscriptions
    ]


main : Program Never
main =
  App.program
     { init = init
     , update = update
     , view = view
     , subscriptions = subscriptions
     }
