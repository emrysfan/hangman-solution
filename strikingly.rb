require 'json'
require 'net/http'
require 'retryable'

class Strikingly
  attr_reader :session_id, :data

  def initialize(player_id)
    @player_id = player_id
    @http = Net::HTTP.new("strikingly-hangman.herokuapp.com")
    @http.read_timeout = 120
  end

  def request(parameters)
    Retryable.retryable(:sleep => 10, :tries => 3, :on => [Net::HTTPRequestTimeOut, Net::HTTPBadGateway, Net::HTTPServerError, Net::ReadTimeout, SocketError]) do
      initheader = {"Content-Type" => "application/json"}
      @http.post("/game/on", parameters.to_json, initheader=initheader)
    end
  end

  def session_request(parameters)
    parameters["sessionId"] = @session_id
    request(parameters)
  end

  def set_session(session_id)
    @session_id = session_id
  end

  def new_game
    parameters = {player_id: @player_id, action: "startGame"}
    response = request(parameters)
    status = response.code.to_i
    if status.between?(200, 210)
      json_response = JSON.parse(response.body)
      @session_id = json_response["sessionId"]
      @data = json_response["data"]
    end
  end

  def next_word
    parameters = {action: "nextWord"}
    session_request(parameters)
  end

  def guess_word(letter)
    parameters = {action: "guessWord", guess: letter}
    session_request(parameters)
  end

  def get_result
    parameters = {action: "getResult"}
    session_request(parameters)
  end

  def submit_result
    parameters = {action: "submitResult"}
    session_request(parameters)
  end

  def self.word_reply(response)
    json_response = JSON.parse(response.body)
    json_response["data"]["word"]
  end

  def self.wrong_guess_count(response)
    json_response = JSON.parse(response.body)
    json_response["data"]["wrongGuessCountOfCurrentWord"]
  end

  def self.total_word_count(response)
    json_response = JSON.parse(response.body)
    json_response["data"]["totalWordCount"]
  end
end
