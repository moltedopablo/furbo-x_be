# Furbo - X

## Intro
This is the backend of our game Furbo-x. It's a collaboration with [h3adHunter](https://github.com/h3adHunter). The game consist of an air hockey with a twist of magic. This game is implemented using Elixir and Phoenix channels feature. The connection with the client is made through websockets. All the game logic is implemented in the backend and the client just render the game state and captures de user input.

The phisical engine used in this game is Rapier, a Rust library that is used through the Rustler library to be used in Elixir.

The frontend is made with React and three.js: [Furbo-x Frontend](https://github.com/h3adHunter/furbo-x_fe)
## How to run
To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

