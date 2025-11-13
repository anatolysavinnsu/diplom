defmodule Hamming do
  def distance(seq1, seq2) do
    list1 = String.graphemes(seq1)
    list2 = String.graphemes(seq2)

    Enum.zip(list1, list2)
    |> Enum.count(fn {char1, char2} -> char1 != char2 end)
  end
end

# Тест
seq1 = "GAGCCTACTAACGGGAT"
seq2 = "CATCGTAATGACGGCCT"
result = Hamming.distance(seq1, seq2)

IO.puts("Расстояние Хэмминга между:")
IO.puts("#{seq1}")
IO.puts("#{seq2}")
IO.puts("Равно: #{result}")