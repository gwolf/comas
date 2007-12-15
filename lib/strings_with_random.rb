#:title: Strings with random
#
# We just add the random class method to our regular String
class String
  # Generates a random string of the specified length (defaults to
  # 8). This string will be composed of characters between 48 and 126
  def self.random(length=8)
    low = 48
    high = 126
    Array.new(length).map {(rand(high - low) + low).chr}.join
  end
end
