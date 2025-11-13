defmodule FASTQQuality do
  @moduledoc """
  Модуль для работы с FASTQ файлами и расчёта качества последовательностей.
  FASTQ формат: каждая запись состоит из 4 строк:
  1. @ID (идентификатор)
  2. SEQUENCE (последовательность)
  3. + (разделитель, иногда с ID)
  4. QUALITY (качество в символьном формате)
  """

  # Константы для Phred качества
  @sanger_offset 33   # Sanger/Illumina 1.8+ format
  @solexa_offset 64   # Old Solexa/Illumina 1.0 format

  @doc """
  Конвертирует символ качества в числовой Phred score.

  ## Параметры
  - quality_char: символ качества (например, 'I')
  - offset: смещение кодировки (по умолчанию 33 для Sanger)

  ## Возвращает
  - Числовой Phred score (например, 40)

  ## Формула
  Phred_score = ASCII(quality_char) - offset
  """
  def phred_score(quality_char, offset \\ @sanger_offset) do
    # Конвертируем символ в его ASCII код и вычитаем смещение
    :binary.first(quality_char) - offset
  end

  @doc """
  Конвертирует Phred score в вероятность ошибки.

  ## Формула
  Error_probability = 10^(-Phred_score / 10)

  ## Пример
  Phred_score = 30 -> Error_prob = 0.001 (1 на 1000)
  """
  def phred_to_error_probability(phred_score) do
    :math.pow(10, -phred_score / 10)
  end

  @doc """
  Конвертирует вероятность ошибки обратно в Phred score.

  ## Формула
  Phred_score = -10 * log10(error_probability)
  """
  def error_probability_to_phred(error_prob) when error_prob > 0 do
    -10 * :math.log10(error_prob)
  end

  def error_probability_to_phred(_), do: nil

  @doc """
  Вычисляет среднее качество для строки качества.
  """
  def average_quality(quality_string, offset \\ @sanger_offset) do
    quality_string
    |> String.to_charlist()
    |> Enum.map(&phred_score(<<&1>>, offset))
    |> then(fn scores ->
      if length(scores) > 0 do
        Enum.sum(scores) / length(scores)
      else
        0
      end
    end)
  end

  @doc """
  Парсит одну запись FASTQ.

  ## Формат FASTQ
  @SEQ_ID
  GATTACA
  +
  !''*(((
  """
  def parse_fastq_record(record) do
    lines = String.split(record, "\n", trim: true)

    case lines do
      [header, sequence, separator, quality] ->
        %{
          id: String.trim_leading(header, "@"),
          sequence: sequence,
          separator: separator,
          quality: quality,
          length: String.length(sequence)
        }

      _ ->
        {:error, "Invalid FASTQ record format"}
    end
  end

  @doc """
  Анализирует строку качества и возвращает статистику.
  """
  def quality_stats(quality_string, offset \\ @sanger_offset) do
    scores =
      quality_string
      |> String.to_charlist()
      |> Enum.map(&phred_score(<<&1>>, offset))

    if length(scores) > 0 do
      %{
        min: Enum.min(scores),
        max: Enum.max(scores),
        mean: Enum.sum(scores) / length(scores),
        length: length(scores),
        scores: scores
      }
    else
      %{min: 0, max: 0, mean: 0, length: 0, scores: []}
    end
  end

  @doc """
  Визуализирует качество в виде простого графика.
  """
  def visualize_quality(quality_string, offset \\ @sanger_offset) do
    scores =
      quality_string
      |> String.to_charlist()
      |> Enum.map(&phred_score(<<&1>>, offset))

    # Создаём простую текстовую визуализацию
    max_score = Enum.max(scores, &>=/2, fn -> 0 end)

    IO.puts("Quality scores: #{inspect(scores)}")
    IO.puts("Visualization:")

    Enum.each(scores, fn score ->
      bars = String.duplicate("█", div(score, 2))
      IO.puts("Q#{String.pad_leading(to_string(score), 2)}: #{bars}")
    end)
  end

  @doc """
  Читает и парсит весь FASTQ файл.
  """
  def parse_fastq_file(content) do
    content
    |> String.split("\n", trim: true)
    |> Enum.chunk_every(4)
    |> Enum.map(fn [header, sequence, separator, quality] ->
      %{
        id: String.trim_leading(header, "@"),
        sequence: sequence,
        separator: separator,
        quality: quality,
        length: String.length(sequence),
        quality_stats: quality_stats(quality)
      }
    end)
  end
end

# Тестовые FASTQ данные
test_fastq_data = """
@SEQ1
GATTACA
+
IIIIIII
@SEQ2
ATCGATCG
+
AAAAFFFF
@SEQ3
GGGCCC
+
!!''**
"""

# Тест
IO.puts("=== FASTQ Quality Score Calculation ===")
IO.puts("")

# Тест 1: Конвертация символов качества
IO.puts("1. Конвертация символов качества в Phred scores:")
test_chars = '!\"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHI'

Enum.each(test_chars, fn char ->
  score = FASTQQuality.phred_score(<<char>>)
  error_prob = FASTQQuality.phred_to_error_probability(score)
  IO.puts("'#{<<char>>}' -> Q#{score} -> Error: #{:erlang.float_to_binary(error_prob, [decimals: 6])}")
end)

IO.puts("")
IO.puts("2. Анализ тестовых FASTQ записей:")

# Парсим тестовые данные
records = FASTQQuality.parse_fastq_file(test_fastq_data)

Enum.each(records, fn record ->
  IO.puts("")
  IO.puts("ID: #{record.id}")
  IO.puts("Sequence: #{record.sequence}")
  IO.puts("Quality: #{record.quality}")
  IO.puts("Quality Stats: min=#{record.quality_stats.min}, max=#{record.quality_stats.max}, mean=#{:erlang.float_to_binary(record.quality_stats.mean, [decimals: 2])}")

  # Визуализация качества для первой последовательности
  if record.id == "SEQ1" do
    FASTQQuality.visualize_quality(record.quality)
  end
end)

IO.puts("")
IO.puts("3. Практические примеры:")

# Пример с реальными значениями качества
example_qualities = [
  "IIIIIII",    # Высокое качество (Illumina)
  "AAAAA",      # Среднее качество
  "!!!!!",      # Низкое качество
  "CAAAA",      # Смешанное качество
]

Enum.each(example_qualities, fn qual_str ->
  stats = FASTQQuality.quality_stats(qual_str)
  IO.puts("")
  IO.puts("Quality string: #{qual_str}")
  IO.puts("Min: Q#{stats.min}, Max: Q#{stats.max}, Mean: Q#{:erlang.float_to_binary(stats.mean, [decimals: 1])}")

  # Показываем вероятности ошибок
  error_probs = Enum.map(stats.scores, &FASTQQuality.phred_to_error_probability/1)
  avg_error = Enum.sum(error_probs) / length(error_probs)
  IO.puts("Average error probability: #{:erlang.float_to_binary(avg_error, [decimals: 6])}")
end)