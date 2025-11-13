defmodule Translation do
  # таблица кодонов
  @genetic_code %{
    "AAA" => "K", "AAC" => "N", "AAG" => "K", "AAT" => "N",
    "ACA" => "T", "ACC" => "T", "ACG" => "T", "ACT" => "T",
    "AGA" => "R", "AGC" => "S", "AGG" => "R", "AGT" => "S",
    "ATA" => "I", "ATC" => "I", "ATG" => "M", "ATT" => "I",
    "CAA" => "Q", "CAC" => "H", "CAG" => "Q", "CAT" => "H",
    "CCA" => "P", "CCC" => "P", "CCG" => "P", "CCT" => "P",
    "CGA" => "R", "CGC" => "R", "CGG" => "R", "CGT" => "R",
    "CTA" => "L", "CTC" => "L", "CTG" => "L", "CTT" => "L",
    "GAA" => "E", "GAC" => "D", "GAG" => "E", "GAT" => "D",
    "GCA" => "A", "GCC" => "A", "GCG" => "A", "GCT" => "A",
    "GGA" => "G", "GGC" => "G", "GGG" => "G", "GGT" => "G",
    "GTA" => "V", "GTC" => "V", "GTG" => "V", "GTT" => "V",
    "TAA" => "*", "TAC" => "Y", "TAG" => "*", "TAT" => "Y",
    "TCA" => "S", "TCC" => "S", "TCG" => "S", "TCT" => "S",
    "TGA" => "*", "TGC" => "C", "TGG" => "W", "TGT" => "C",
    "TTA" => "L", "TTC" => "F", "TTG" => "L", "TTT" => "F"
  }

  # Старт-кодон
  @start_codon "ATG"
  # Стоп-кодоны
  @stop_codons ["TAA", "TAG", "TGA"]

  def translate(dna) do
    uppercase_dna = String.upcase(dna)

    # Ищем старт-кодон
    case String.split(uppercase_dna, "ATG", parts: 2) do
      [_, coding_region] ->
        # Нашли ATG - начинаем перевод с этого места
        coding_region
        |> String.codepoints()
        |> Enum.chunk_every(3)
        |> translate_codons()
        |> Enum.join()

      [_] ->
        # ATG не найден - возвращаем пустую строку
        ""
    end
  end

  defp translate_codons(codons) do
    Enum.reduce_while(codons, [], fn codon, acc ->
      if length(codon) == 3 do
        amino_acid = translate_codon(codon)

        if amino_acid == "*" do
          # Встретили стоп-кодон - останавливаемся
          {:halt, acc}
        else
          # Продолжаем собирать аминокислоты
          {:cont, acc ++ [amino_acid]}
        end
      else
        # Неполный кодон - останавливаемся
        {:halt, acc}
      end
    end)
  end

  defp translate_codon(codon) do
    codon_str = Enum.join(codon)
    @genetic_code[codon_str] || "?"
  end
end

# Тест
test_sequences = [
  # Полная последовательность со стартом и стопом
  "AAAATGGCCTGAACCCGTATAGTTT",                    # Старт: ATG, Стоп: TAG

  # Только старт-кодон, без стопа
  "TTTATGGCCTGAACCCG",                            # Старт: ATG, Стоп: нет

  # Без старт-кодона
  "AAAACCCTTTGGG",                                # Старт: нет, Стоп: нет

  # Старт и сразу стоп
  "ATGTAATTT",                                    # Старт: ATG, Стоп: TAA

  # Несколько старт-кодонов (должен взять первый)
  "ATGAAAATGCCCTGA",                              # Старт: первый ATG, Стоп: TGA

  # Реальная последовательность гена
  "ATGGCCTGAACCCGTATAG",                          # Старт: ATG, Стоп: TAG

  # Последовательность без стоп-кодона в конце
  "ATGGCCTGAACCCG",                               # Старт: ATG, Стоп: нет

  # Пустая строка
  "",                                             # Пустая

  # Только старт-кодон
  "ATG",                                          # Только старт
]

IO.puts("=== Тестирование перевода DNA -> Protein ===")
IO.puts("(Начинаем со старт-кодона ATG, заканчиваем на стоп-кодоне)\n")

Enum.each(test_sequences, fn dna ->
  protein = Translation.translate(dna)

  # форматируем вывод
  IO.puts("DNA: #{dna}")
  IO.puts("Protein: #{if protein == "", do: "(нет белка)", else: protein}")
  IO.puts("Длина: #{String.length(protein)} аминокислот")

  # Показываем какие кодоны были обработаны
  if protein != "" do
    IO.puts("Белок: #{protein}")
  end

  IO.puts("---")
end)

# Дополнительные тесты с объяснением
IO.puts("\n=== Подробный разбор примеров ===")

example1 = "AAAATGGCCTGAACCCGTATAGTTT"
IO.puts("\nПример 1: #{example1}")
IO.puts("Разбор:")
IO.puts("- Находим первый ATG на позиции 3")
IO.puts("- Начинаем перевод с: GCCTGAACCCGTATAGTTT")
IO.puts("- Разбиваем на кодоны: GCC TGA ACC CGT ATA GTT")
IO.puts("- TGA - стоп-кодон, перевод останавливается")
IO.puts("- Результат: #{Translation.translate(example1)}")

example2 = "ATGTAATTT"
IO.puts("\nПример 2: #{example2}")
IO.puts("Разбор:")
IO.puts("- Начинаем с ATG")
IO.puts("- Следующий кодон: TAA (стоп-кодон)")
IO.puts("- Перевод сразу останавливается")
IO.puts("- Результат: #{Translation.translate(example2)}")

# Сравнение с оригинальной последовательностью из задания
IO.puts("\n=== Оригинальная тестовая последовательность ===")
original_dna = "ATGGCCATTGTAATGGGCCGCTGAAAGGGTGCCCGATAG"
original_protein = Translation.translate(original_dna)

IO.puts("DNA: #{original_dna}")
IO.puts("Protein: #{original_protein}")

# Покажем пошагово что происходит с оригинальной последовательностью
IO.puts("\nПошаговый разбор оригинальной последовательности:")
IO.puts("1. Начинаем с ATG")
IO.puts("2. Кодоны: GCC ATT GTA ATG GGC CGC TGA AAG GGT GCC CGA TAG")
IO.puts("3. Встречаем TGA (стоп-кодон) на 7-й позиции")
IO.puts("4. Белок до стоп-кодона: M A I V M G R")
IO.puts("5. Результат: #{original_protein}")