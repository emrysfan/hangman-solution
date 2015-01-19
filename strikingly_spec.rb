require 'strikingly'

describe Strikingly, "#new_game" do
  it "start a new session" do
    strikingly = Strikingly.new("test@gmail.com")
    expect(strikingly.session_id).to be_nil
    expect(strikingly.data).to be_nil
    strikingly.new_game
    expect(strikingly.session_id).not_to be_nil
    expect(strikingly.data).not_to be_nil
  end

  context "with game on" do
    strikingly = Strikingly.new("test@gmail.com")
    strikingly.new_game

    it "return a new word" do
      response = strikingly.next_word
      puts response.body
      expect(response.code.to_i).to eql(200)
    end
  end
end
