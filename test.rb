require 'hangman'

api = Strikingly.new("test@gmail.com")
hangman = Hangman.new(api)

hangman.initialize_redis_database

hangman.solve

hangman.submit
