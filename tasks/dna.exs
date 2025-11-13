defmodule DNA do
  def reverse_complement(dna) do
    dna
    |> String.reverse()
    |> String.graphemes()
    |> Enum.map(fn
      "A" -> "T"
      "T" -> "A"
      "C" -> "G"
      "G" -> "C"
      char -> char  # Оставляем другие символы как есть
    end)
    |> Enum.join("")
  end
end

# Тест
dna_sequence = "ATCG"
result1 = DNA.reverse_complement(dna_sequence)
result2 = DNA.reverse_complement2(dna_sequence)

IO.puts("Исходная последовательность: #{dna_sequence}")
IO.puts("Обратный комплемент (способ 1): #{result1}")
IO.puts("Обратный комплемент (способ 2): #{result2}")