test = """
characters "test" {
  name = "Test"
  skills = {
    unarmed = 50
    dodge = 50
  }
}
"""

Elias.parse(test)
|> IO.inspect()