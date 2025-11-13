defmodule MarkovModel do
  @moduledoc """
  Модуль для создания и использования Марковских моделей DNA последовательностей.
  Марковская модель предсказывает следующий символ на основе предыдущих символов (порядок модели).
  """

  @bases ["A", "C", "G", "T"]
  @default_order 2

  @doc """
  Обучает Марковскую модель на наборе последовательностей.

  ## Параметры
  - sequences: список DNA последовательностей
  - order: порядок модели (сколько предыдущих символов учитывать)

  ## Возвращает
  - Обученную модель: %{transition_counts: ..., order: ..., bases: ...}
  """
  def train_model(sequences, order \\ @default_order) do
    transition_counts = build_transition_counts(sequences, order)

    %{
      transition_counts: transition_counts,
      order: order,
      bases: @bases,
      total_sequences: length(sequences)
    }
  end

  defp build_transition_counts(sequences, order) do
    sequences
    |> Enum.flat_map(&extract_transitions(&1, order))
    |> Enum.reduce(%{}, fn {context, next_char}, acc ->
      Map.update(acc, context, %{next_char => 1}, fn counts ->
        Map.update(counts, next_char, 1, &(&1 + 1))
      end)
    end)
  end

  defp extract_transitions(sequence, order) do
    sequence
    |> String.upcase()
    |> String.graphemes()
    |> Enum.chunk_every(order + 1, 1)
    |> Enum.filter(&(length(&1) == order + 1))
    |> Enum.map(fn chunk ->
      context = Enum.take(chunk, order) |> Enum.join()
      next_char = List.last(chunk)
      {context, next_char}
    end)
  end

  @doc """
  Преобразует counts в вероятности.
  """
  def calculate_probabilities(model) do
    transition_probs =
      model.transition_counts
      |> Enum.map(fn {context, counts} ->
        total = Enum.sum(Map.values(counts))
        probabilities =
          Enum.map(counts, fn {char, count} ->
            {char, count / total}
          end)
          |> Enum.into(%{})
        {context, probabilities}
      end)
      |> Enum.into(%{})

    Map.put(model, :transition_probabilities, transition_probs)
  end

  @doc """
  Генерирует новую последовательность с использованием обученной модели.

  ## Параметры
  - model: обученная Марковская модель
  - length: длина генерируемой последовательности
  - starting_context: начальный контекст (опционально)
  """
  def generate_sequence(model, length, starting_context \\ nil) do
    probs_model = calculate_probabilities(model)
    _order = model.order  # Добавил подчёркивание

    # Выбираем начальный контекст
    initial_context =
      starting_context ||
        select_random_context(probs_model.transition_probabilities)

    do_generate_sequence(probs_model, length, initial_context, initial_context)
  end

  defp select_random_context(transition_probs) do
    if map_size(transition_probs) > 0 do
      contexts = Map.keys(transition_probs)
      Enum.random(contexts)
    else
      # Если нет контекстов, генерируем случайный
      Enum.take(Stream.repeatedly(fn -> Enum.random(@bases) end), 2)
      |> Enum.join()
    end
  end

  defp do_generate_sequence(_model, 0, _current_context, acc), do: acc

  defp do_generate_sequence(model, remaining_length, current_context, acc) do
    probabilities = Map.get(model.transition_probabilities, current_context, %{})

    next_char =
      if map_size(probabilities) > 0 do
        select_next_char(probabilities)
      else
        # Если контекст не найден, выбираем случайный символ
        Enum.random(@bases)
      end

    new_context =
      if String.length(current_context) == model.order do
        # Исправлено: правильный способ получить подстроку без первого символа
        String.slice(current_context, 1..-1//1) <> next_char
      else
        current_context <> next_char
      end

    new_sequence = acc <> next_char

    do_generate_sequence(model, remaining_length - 1, new_context, new_sequence)
  end

  defp select_next_char(probabilities) do
    rand = :rand.uniform()

    probabilities
    |> Enum.reduce_while(0.0, fn {char, prob}, cumulative ->
      new_cumulative = cumulative + prob
      if rand <= new_cumulative do
        {:halt, char}
      else
        {:cont, new_cumulative}
      end
    end)
  end

  @doc """
  Оценивает логарифмическую вероятность последовательности по модели.
  Полезно для сравнения, насколько последовательность "похожа" на тренировочные данные.
  """
  def sequence_log_probability(model, sequence) do
    probs_model = calculate_probabilities(model)
    order = model.order

    sequence
    |> String.upcase()
    |> String.graphemes()
    |> Enum.chunk_every(order + 1, 1)
    |> Enum.filter(&(length(&1) == order + 1))
    |> Enum.map(fn chunk ->
      context = Enum.take(chunk, order) |> Enum.join()
      next_char = List.last(chunk)
      prob = get_transition_probability(probs_model, context, next_char)
      :math.log(prob)
    end)
    |> Enum.sum()
  end

  defp get_transition_probability(model, context, next_char) do
    probs = Map.get(model.transition_probabilities, context, %{})
    Map.get(probs, next_char, 0.001)  # small pseudocount для неизвестных переходов
  end

  @doc """
  Сравнивает две модели с помощью perplexity.
  Чем ниже perplexity - тем лучше модель предсказывает данные.
  """
  def model_perplexity(model, test_sequences) do
    total_log_prob =
      test_sequences
      |> Enum.map(&sequence_log_probability(model, &1))
      |> Enum.sum()

    total_transitions =
      test_sequences
      |> Enum.flat_map(&extract_transitions(&1, model.order))
      |> length()

    if total_transitions > 0 do
      :math.exp(-total_log_prob / total_transitions)
    else
      :infinity
    end
  end

  @doc """
  Визуализирует матрицу переходов для модели.
  """
  def visualize_transitions(model, max_contexts \\ 10) do
    probs_model = calculate_probabilities(model)

    IO.puts("Марковская модель порядка #{model.order}")
    IO.puts("=" <> String.duplicate("=", 50))

    probs_model.transition_probabilities
    |> Enum.take(max_contexts)
    |> Enum.each(fn {context, transitions} ->
      IO.puts("Контекст: #{context}")

      transitions
      |> Enum.sort_by(fn {_char, prob} -> -prob end)
      |> Enum.each(fn {char, prob} ->
        bar = String.duplicate("█", round(prob * 20))
        IO.puts("  #{char}: #{:erlang.float_to_binary(prob, [decimals: 3])} #{bar}")
      end)
      IO.puts("")
    end)
  end

  @doc """
  Создает смешанную модель из нескольких наборов данных.
  Полезно для создания моделей, представляющих разные биологические условия.
  """
  def mix_models(models, weights \\ nil) do
    default_weight = 1.0 / length(models)
    weights = weights || List.duplicate(default_weight, length(models))

    # Проверяем что все модели одного порядка
    orders = Enum.map(models, & &1.order) |> Enum.uniq()
    if length(orders) != 1 do
      raise "Все модели должны быть одного порядка"
    end

    order = hd(orders)

    # Смешиваем counts
    mixed_counts =
      Enum.zip(models, weights)
      |> Enum.flat_map(fn {model, weight} ->
        Enum.map(model.transition_counts, fn {context, counts} ->
          weighted_counts =
            Enum.map(counts, fn {char, count} ->
              {char, count * weight}
            end)
            |> Enum.into(%{})
          {context, weighted_counts}
        end)
      end)
      |> Enum.reduce(%{}, fn {context, new_counts}, acc ->
        Map.update(acc, context, new_counts, fn existing_counts ->
          Map.merge(existing_counts, new_counts, fn _char, count1, count2 ->
            count1 + count2
          end)
        end)
      end)

    %{
      transition_counts: mixed_counts,
      order: order,
      bases: @bases,
      total_sequences: Enum.sum(Enum.map(models, & &1.total_sequences))
    }
  end
end

# Тренировочные данные - разные типы последовательностей
training_sequences = [
  # Богатые AT последовательности (характерны для промоторов)
  "ATATATATATAT",
  "ATAATATATATA",
  "TATATATATATA",
  "ATATATAATATA",

  # Богатые GC последовательности (характерны для генов)
  "GCGCGCGCGCGC",
  "GGCGCGCGCGCG",
  "CGCGCGCGCGCG",
  "GCGGCGCGCGCG",

  # Случайные последовательности
  "ACGTACGTACGT",
  "TGACTGACTGAC",
  "CAGTCAGTCAGT",
  "GTACGTACGTAC"
]

IO.puts("=== Обучение Марковской модели ===")
IO.puts("")

# Обучаем модели разных порядков
models =
  [1, 2, 3]
  |> Enum.map(fn order ->
    IO.puts("Обучение модели порядка #{order}...")
    model = MarkovModel.train_model(training_sequences, order)
    {order, model}
  end)
  |> Enum.into(%{})

IO.puts("")
IO.puts("=== Генерация последовательностей ===")
IO.puts("")

# Генерируем последовательности с разными моделями
Enum.each([1, 2, 3], fn order ->
  model = models[order]

  IO.puts("Модель порядка #{order}:")
  Enum.each(1..3, fn _i ->  # Добавил подчёркивание
    sequence = MarkovModel.generate_sequence(model, 20)
    IO.puts("  #{sequence}")
  end)
  IO.puts("")
end)

IO.puts("")
IO.puts("=== Визуализация переходов ===")
IO.puts("")

# Покажем матрицу переходов для модели порядка 1
MarkovModel.visualize_transitions(models[1])

IO.puts("")
IO.puts("=== Оценка качества моделей ===")
IO.puts("")

# Создадим тестовые последовательности
test_sequences = [
  "ATATATATAT",      # Похожа на тренировочные
  "GCGCGCGCGC",      # Похожа на тренировочные
  "AAAAAAAAAA",      # Очень простая
  "ACGTACGTAC",      # Случайная
  "TTTTTTTTTT"       # Очень простая
]

# Оценим perplexity для каждой модели
Enum.each([1, 2, 3], fn order ->
  model = models[order]
  perplexity = MarkovModel.model_perplexity(model, test_sequences)

  IO.puts("Модель порядка #{order}:")
  IO.puts("  Perplexity: #{:erlang.float_to_binary(perplexity, [decimals: 2])}")

  # Оценим логарифмическую вероятность для каждой тестовой последовательности
  test_sequences
  |> Enum.with_index()
  |> Enum.each(fn {seq, i} ->
    log_prob = MarkovModel.sequence_log_probability(model, seq)
    IO.puts("  Seq #{i + 1} logprob: #{:erlang.float_to_binary(log_prob, [decimals: 2])}")
  end)
  IO.puts("")
end)

IO.puts("")
IO.puts("=== Специализированные модели ===")
IO.puts("")

# Создадим специализированные модели для разных типов последовательностей
at_rich_sequences = Enum.take(training_sequences, 4)
gc_rich_sequences = Enum.slice(training_sequences, 4..7)
random_sequences = Enum.slice(training_sequences, 8..11)

at_model = MarkovModel.train_model(at_rich_sequences, 2)
gc_model = MarkovModel.train_model(gc_rich_sequences, 2)
_random_model = MarkovModel.train_model(random_sequences, 2)  # Добавил подчёркивание

IO.puts("AT-rich модель:")
Enum.each(1..2, fn _i ->  # Добавил подчёркивание
  seq = MarkovModel.generate_sequence(at_model, 15)
  at_count = String.length(seq) - String.length(String.replace(seq, ["A", "T"], ""))
  IO.puts("  #{seq} (AT content: #{at_count}/#{String.length(seq)})")
end)

IO.puts("")
IO.puts("GC-rich модель:")
Enum.each(1..2, fn _i ->  # Добавил подчёркивание
  seq = MarkovModel.generate_sequence(gc_model, 15)
  gc_count = String.length(seq) - String.length(String.replace(seq, ["G", "C"], ""))
  IO.puts("  #{seq} (GC content: #{gc_count}/#{String.length(seq)})")
end)

IO.puts("")
IO.puts("=== Смешанная модель ===")
IO.puts("")

# Создадим смешанную модель
mixed_model = MarkovModel.mix_models([at_model, gc_model], [0.7, 0.3])

IO.puts("Смешанная модель (70% AT-rich, 30% GC-rich):")
Enum.each(1..3, fn _i ->  # Добавил подчёркивание
  seq = MarkovModel.generate_sequence(mixed_model, 20)
  at_count = String.length(seq) - String.length(String.replace(seq, ["A", "T"], ""))
  gc_count = String.length(seq) - String.length(String.replace(seq, ["G", "C"], ""))
  IO.puts("  #{seq} (AT: #{at_count}, GC: #{gc_count})")
end)

IO.puts("")
IO.puts("=== Сравнение с реальными биологическими данными ===")
IO.puts("")

# Протестируем на реальных биологических паттернах
biological_patterns = [
  "TATAAA",      # TATA box (промотор)
  "GGGCGG",      # GC box (промотор)
  "ATG",         # Start codon
  "TAA", "TAG", "TGA",  # Stop codons
  "CTGCAG"       # PstI restriction site
]

IO.puts("Вероятности биологических паттернов в модели порядка 2:")
model = models[2]

Enum.each(biological_patterns, fn pattern ->
  if String.length(pattern) >= 3 do
    log_prob = MarkovModel.sequence_log_probability(model, pattern)
    IO.puts("  #{pattern}: #{:erlang.float_to_binary(log_prob, [decimals: 2])}")
  end
end)