require 'json'
require 'redis'
require 'logger'
require 'strikingly'

class Hangman
  @@vowels = ['A', 'E', 'I', 'O', 'U', 'Y']
  @@wordlist_url = "http://www.mieliestronk.com/corncob_caps.txt"

  def initialize(api)
    @redis = Redis.new
    @api =  api
    @logger = Logger.new(STDOUT)
  end

  def self.calculate_frequency(words)
    letter_frequency_hash = {}
    letter_frequency_hash.default = 0

    words.each do |word|
      word.each_char do |char|
        letter_frequency_hash[char.to_sym] += 1
      end
    end

    letter_frequency_array = letter_frequency_hash.to_a
    letter_frequency_array.sort! { |x, y| y[1] <=> x[1] }
    letter_frequency_array.collect! { |item| item[0].to_s }
    letter_order_by_frequency = letter_frequency_array.join ""

    return letter_order_by_frequency
  end

  def initialize_redis_database()
    url = URI(@@wordlist_url)
    words_string = Net::HTTP.get(url)
    words_array = words_string.split("\r\n")

    max_word_length = 1
    words_array.each do |word|
      @redis.set "#{word.length}:#{word}", 1
      max_word_length = word.length if word.length > max_word_length 
    end

    for word_length in (1..max_word_length)
      words_in_specific_length = @redis.keys("#{word_length}:*")
      words_frequency = Hangman.calculate_frequency(words_in_specific_length)
      @redis.set("F#{word_length}", words_frequency.split(":")[1])
    end
  end

  def solve
    @api.new_game
    @guess_limit = @api.data["numberOfGuessAllowedForEachWord"]
    @number_of_words = @api.data["numberOfWordsToGuess"]

    @logger.info("Game started")
    @logger.info("Session Id: #{@api.session_id}")
    @logger.info("numberOfGuessAllowedForEachWord: #{@guess_limit}")
    @logger.info("numberOfWordsToGuess: #{@number_of_words}")
    
    @number_of_words.times do
      response = @api.next_word
      word = Strikingly.word_reply(response)
      @logger.info("New word: #{word}")
      result = guess(word, "", true)
      @logger.info("Guess result: #{result}")
    end

    response = @api.get_result
    json_response = JSON.parse(response.body)
    score_data = json_response["data"]
    score_data.each do |key, value|
      @logger.info("#{key}: #{value}")
    end
  end

  def submit
    response = @api.submit_result
    json_response = JSON.parse(response.body)
    score_data = json_response["data"]
    score_data.each do |key, value|
      @logger.info("#{key}: #{value}")
    end
  end

  def guess(word, exclude_letters="", vowel_check=false)
    if not word.include?("*")
      return word
    end

    if vowel_check == true
      letter_order_by_frequency = @redis.get("F#{word.length}")
      vowel_letter_array = letter_order_by_frequency.split("").select { |vowel| @@vowels.include?(vowel) }
      vowel_letters = vowel_letter_array.join("")
      vowel_letters.each_char do |vowel|
        guess_response = @api.guess_word(vowel)
        @logger.info("Make a guess: #{vowel}")
        exclude_letters.insert(-1, vowel)
        word_reply = Strikingly.word_reply(guess_response)
        @logger.info("Reply word: #{word_reply}")
        wrong_guess_count = Strikingly.wrong_guess_count(guess_response)

        if not word.eql?(word_reply) && wrong_guess_count < @guess_limit
          return guess(word_reply, exclude_letters)
        end

        if wrong_guess_count >= @guess_limit
          @logger.info("Faild: #{word}")
          return word
        end
      end
    end

    pattern = word.gsub("*", "?").insert(0, "#{word.length}:")
    words_matched = @redis.keys(pattern)
    letter_order_by_frequency = Hangman.calculate_frequency(words_matched)
    letter_order_by_frequency.delete!(":#{word.length}")
    letter_order_by_frequency.delete!(exclude_letters)

    letter_order_by_frequency.each_char do |letter|
      @logger.info("Make a guess: #{letter}")
      guess_response = @api.guess_word(letter)
      exclude_letters.insert(-1, letter)
      word_reply = Strikingly.word_reply(guess_response)
      @logger.info("Reply word: #{word_reply}")
      wrong_guess_count = Strikingly.wrong_guess_count(guess_response)

      if not word.eql?(word_reply) && wrong_guess_count < @guess_limit
        return guess(word_reply, exclude_letters)
      end

      if wrong_guess_count >= @guess_limit
        @logger.info("Faild: #{word}")
        return word
      end
    end

    @logger.info("Faild: #{word}")
    return word
  end

end
