efmodule KMerCounting do
  @moduledoc """
  Модуль для подсчёта k-меров в биологических последовательностях.
  k-мер - это подстрока длиной k, используемая во многих биоинформатических алгоритмах.
  """

  @doc """
  Основная функция для подсчёта k-меров в последовательности.

  ## Параметры
  - sequence: DNA последовательность
  - k: длина k-мера

  ## Возвращает
  - Map с k-мерами как ключи и количествами как значения

  ## Пример
  count_kmers("ATCG", 2) -> %{"AT" => 1, "TC" => 1, "CG" => 1}
  """
  def count_kmers(sequence, k) when k > 0 and k <= byte_size(sequence) do
    sequence
    |> String.upcase()
    |> String.graphemes()
    |> Enum.chunk_every(k, 1)
    |> Enum.filter(&(length(&1) == k))  # Фильтруем неполные k-меры в конце
    |> Enum.map(&Enum.join/1)
    |> Enum.reduce(%{}, fn kmer, acc ->
      Map.update(acc, kmer, 1, &(&1 + 1))
    end)
  end

  def count_kmers(_sequence, _k), do: %{}

  @doc """
  Подсчёт k-меров с использованием потоков для больших последовательностей.
  Более эффективен по памяти.
  """
  def count_kmers_stream(sequence, k) when k > 0 and k <= byte_size(sequence) do
    sequence
    |> String.upcase()
    |> String.codepoints()
    |> Stream.chunk_every(k, 1)
    |> Stream.filter(&(length(&1) == k))
    |> Stream.map(&Enum.join/1)
    |> Enum.reduce(%{}, fn kmer, acc ->
      Map.update(acc, kmer, 1, &(&1 + 1))
    end)
  end

  @doc """
  Находит наиболее частые k-меры.

  ## Параметры
  - sequence: DNA последовательность
  - k: длина k-мера
  - top_n: количество топ k-меров для возврата

  ## Возвращает
  - Список кортежей {kmer, count} отсортированный по убыванию частоты
  """
  def most_frequent_kmers(sequence, k, top_n \\ 10) do
    count_kmers(sequence, k)
    |> Enum.sort_by(fn {_kmer, count} -> -count end)
    |> Enum.take(top_n)
  end

  @doc """
  Вычисляет частоты k-меров (нормализованные количества).

  ## Возвращает
  - Map с k-мерами как ключи и частотами (0.0 - 1.0) как значения
  """
  def kmer_frequencies(sequence, k) do
    counts = count_kmers(sequence, k)
    total = Enum.reduce(counts, 0, fn {_kmer, count}, acc -> acc + count end)

    if total > 0 do
      Enum.map(counts, fn {kmer, count} ->
        {kmer, count / total}
      end)
      |> Enum.into(%{})
    else
      %{}
    end
  end

  @doc """
  Генерирует все возможные k-меры для заданного k.
  Полезно для инициализации или проверки покрытия.

  ## Пример
  all_possible_kmers(2) -> ["AA", "AC", "AG", "AT", "CA", ...]
  """
  def all_possible_kmers(k) when k > 0 do
    bases = ["A", "C", "G", "T"]

    bases
    |> generate_kmers_recursive(k)
    |> Enum.map(&Enum.join/1)
  end

  defp generate_kmers_recursive(bases, 1) do
    Enum.map(bases, &[&1])
  end

  defp generate_kmers_recursive(bases, k) when k > 1 do
    for base <- bases,
        suffix <- generate_kmers_recursive(bases, k - 1) do
      [base | suffix]
    end
  end

  @doc """
  Проверяет покрытие - какие возможные k-меры присутствуют в последовательности.

  ## Возвращает
  - %{present: список присутствующих, missing: список отсутствующих, all_possible: список всех возможных, coverage: процент покрытия}
  """
  def kmer_coverage(sequence, k) do
    observed = count_kmers(sequence, k) |> Map.keys()
    all_possible = all_possible_kmers(k)

    %{
      present: observed,
      missing: all_possible -- observed,
      all_possible: all_possible,
      coverage: length(observed) / length(all_possible)
    }
  end

  @doc """
  Находит уникальные k-меры (встречаются только один раз).
  """
  def unique_kmers(sequence, k) do
    count_kmers(sequence, k)
    |> Enum.filter(fn {_kmer, count} -> count == 1 end)
    |> Enum.map(&elem(&1, 0))
  end

  @doc """
  Вычисляет энтропию k-меров (мера разнообразия).
  Чем выше энтропия - тем более разнообразны k-меры.
  """
  def kmer_entropy(sequence, k) do
    frequencies = kmer_frequencies(sequence, k)

    frequencies
    |> Enum.reduce(0.0, fn {_kmer, freq}, acc ->
      if freq > 0 do
        acc - freq * :math.log2(freq)
      else
        acc
      end
    end)
  end

  @doc """
  Сравнивает две последовательности по их k-мерным профилям.

  ## Возвращает
  - Коэффициент Жаккара (мера сходства)
  """
  def compare_sequences(seq1, seq2, k) do
    kmers1 = count_kmers(seq1, k) |> Map.keys() |> MapSet.new()
    kmers2 = count_kmers(seq2, k) |> Map.keys() |> MapSet.new()

    intersection = MapSet.intersection(kmers1, kmers2) |> MapSet.size()
    union = MapSet.union(kmers1, kmers2) |> MapSet.size()

    if union > 0 do
      intersection / union
    else
      0.0
    end
  end

  @doc """
  Визуализирует распределение k-меров в виде гистограммы.
  """
  def visualize_kmer_distribution(sequence, k, max_bars \\ 20) do
    counts = count_kmers(sequence, k)

    if map_size(counts) > 0 do
      sorted = Enum.sort_by(counts, fn {_kmer, count} -> -count end)

      IO.puts("Распределение #{k}-меров:")
      IO.puts(String.duplicate("=", 40))

      {top_kmers, rest} = Enum.split(sorted, max_bars)

      Enum.each(top_kmers, fn {kmer, count} ->
        bar = String.duplicate("█", div(count, 2))
        IO.puts("#{String.pad_trailing(kmer, k)}: #{String.pad_leading(to_string(count), 4)} #{bar}")
      end)

      if length(rest) > 0 do
        IO.puts("... и ещё #{length(rest)} #{k}-меров")
      end

      total_kmers = Enum.reduce(counts, 0, fn {_, count}, acc -> acc + count end)
      unique_kmers = map_size(counts)

      IO.puts("\nСтатистика:")
      IO.puts("Всего #{k}-меров: #{total_kmers}")
      IO.puts("Уникальных #{k}-меров: #{unique_kmers}")
      IO.puts("Энтропия: #{:erlang.float_to_binary(kmer_entropy(sequence, k), [decimals: 3])}")
    else
      IO.puts("Нет #{k}-меров в последовательности")
    end
  end
end

# Тестовые последовательности
test_sequences = [
  {"ATCGATCG", 2},
  {"AAAAAA", 3},
  {"ACGTACGT", 4},
  {"AT", 2},
  {"GATTACA", 2},
]

IO.puts("=== Базовый подсчёт k-меров ===")
IO.puts("")

Enum.each(test_sequences, fn {sequence, k} ->
  counts = KMerCounting.count_kmers(sequence, k)

  IO.puts("Последовательность: #{sequence}")
  IO.puts("k = #{k}")
  IO.puts("K-меры: #{inspect(counts)}")
  IO.puts("---")
end)

IO.puts("")
IO.puts("=== Наиболее частые k-меры ===")
IO.puts("")

test_seq = "ATCGATCGATCG"
[2, 3, 4]
|> Enum.each(fn k ->
  top_kmers = KMerCounting.most_frequent_kmers(test_seq, k, 5)

  IO.puts("Топ #{k}-меры в '#{test_seq}':")
  Enum.each(top_kmers, fn {kmer, count} ->
    IO.puts("  #{kmer}: #{count} раз")
  end)
  IO.puts("")
end)

IO.puts("")
IO.puts("=== Покрытие k-меров ===")
IO.puts("")

# Тестируем покрытие для разных k
coverage_test_seq = "ACGTACGT"
[2, 3]
|> Enum.each(fn k ->
  coverage = KMerCounting.kmer_coverage(coverage_test_seq, k)

  IO.puts("Покрытие #{k}-меров в '#{coverage_test_seq}':")
  IO.puts("  Всего возможных: #{length(coverage.all_possible)}")
  IO.puts("  Присутствует: #{length(coverage.present)}")
  IO.puts("  Отсутствует: #{length(coverage.missing)}")
  IO.puts("  Покрытие: #{:erlang.float_to_binary(coverage.coverage * 100, [decimals: 1])}%")
  IO.puts("")
end)

IO.puts("")
IO.puts("=== Сравнение последовательностей ===")
IO.puts("")

seq1 = "ATCGATCG"
seq2 = "ATCGCTCG"  # Одна мутация
seq3 = "GGGGGGGG"  # Совсем другая

similarity_12 = KMerCounting.compare_sequences(seq1, seq2, 2)
similarity_13 = KMerCounting.compare_sequences(seq1, seq3, 2)

IO.puts("Сходство между '#{seq1}' и '#{seq2}': #{:erlang.float_to_binary(similarity_12, [decimals: 3])}")
IO.puts("Сходство между '#{seq1}' и '#{seq3}': #{:erlang.float_to_binary(similarity_13, [decimals: 3])}")

IO.puts("")
IO.puts("=== Визуализация распределения ===")
IO.puts("")

# Визуализируем распределение для интересной последовательности
interesting_seq = "ATCG" <> "GATTACA" <> "TGCATGC"
KMerCounting.visualize_kmer_distribution(interesting_seq, 2)

IO.puts("")
IO.puts("=== Анализ энтропии ===")
IO.puts("")

# Сравним энтропию разных последовательностей
low_entropy_seq = "AAAAAA"
high_entropy_seq = "ACGTACGT"

entropy_low = KMerCounting.kmer_entropy(low_entropy_seq, 2)
entropy_high = KMerCounting.kmer_entropy(high_entropy_seq, 2)

IO.puts("Энтропия '#{low_entropy_seq}': #{:erlang.float_to_binary(entropy_low, [decimals: 3])}")
IO.puts("Энтропия '#{high_entropy_seq}': #{:erlang.float_to_binary(entropy_high, [decimals: 3])}")
IO.puts("(Чем выше энтропия - тем более разнообразна последовательность)")

IO.puts("")
IO.puts("=== Все возможные k-меры ===")
IO.puts("")

# Покажем все возможные k-меры для маленького k
IO.puts("Все возможные 2-меры:")
kmers_2 = KMerCounting.all_possible_kmers(2)
IO.puts("#{Enum.join(kmers_2, ", ")}")
IO.puts("Всего: #{length(kmers_2)}")

IO.puts("")
IO.puts("Все возможные 3-меры (первые 10):")
kmers_3 = KMerCounting.all_possible_kmers(3)
IO.puts("#{Enum.join(Enum.take(kmers_3, 10), ", ")}...")
IO.puts("Всего: #{length(kmers_3)}")