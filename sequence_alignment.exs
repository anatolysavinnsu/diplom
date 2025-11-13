defmodule SequenceAlignment do
  @moduledoc """
  Модуль для выравнивания биологических последовательностей.
  Реализует алгоритмы Needleman-Wunsch (глобальное выравнивание)
  и Smith-Waterman (локальное выравнивание).
  """

  # Параметры по умолчанию для штрафов
  @default_gap_penalty -1
  @default_mismatch_penalty -1
  @default_match_score 1

  @doc """
  Глобальное выравнивание Needleman-Wunsch.
  Выравнивает последовательности по всей длине.
  """
  def needleman_wunsch(seq1, seq2, opts \\ []) do
    gap_penalty = opts[:gap_penalty] || @default_gap_penalty
    mismatch_penalty = opts[:mismatch_penalty] || @default_mismatch_penalty
    match_score = opts[:match_score] || @default_match_score

    # Инициализируем матрицу
    {matrix, _n, _m} = initialize_matrix(seq1, seq2, gap_penalty)

    # Заполняем матрицу
    filled_matrix = fill_matrix(matrix, seq1, seq2, match_score, mismatch_penalty, gap_penalty)

    # Трассировка назад для нахождения оптимального выравнивания
    {aligned1, aligned2, score} = traceback(filled_matrix, seq1, seq2, match_score, mismatch_penalty, gap_penalty)

    %{
      aligned_seq1: aligned1,
      aligned_seq2: aligned2,
      score: score,
      identity: calculate_identity(aligned1, aligned2)
    }
  end

  @doc """
  Локальное выравнивание Smith-Waterman.
  Находит регионы локального сходства.
  """
  def smith_waterman(seq1, seq2, opts \\ []) do
    gap_penalty = opts[:gap_penalty] || @default_gap_penalty
    mismatch_penalty = opts[:mismatch_penalty] || @default_mismatch_penalty
    match_score = opts[:match_score] || @default_match_score

    {matrix, _n, _m} = initialize_matrix_smith_waterman(seq1, seq2)
    filled_matrix = fill_matrix_smith_waterman(matrix, seq1, seq2, match_score, mismatch_penalty, gap_penalty)
    {aligned1, aligned2, score} = traceback_smith_waterman(filled_matrix, seq1, seq2, match_score, mismatch_penalty, gap_penalty)

    %{
      aligned_seq1: aligned1,
      aligned_seq2: aligned2,
      score: score,
      identity: calculate_identity(aligned1, aligned2)
    }
  end

  ## Needleman-Wunsch Implementation

  defp initialize_matrix(seq1, seq2, gap_penalty) do
    n = String.length(seq1)
    m = String.length(seq2)

    # Создаём матрицу (n+1) x (m+1)
    matrix = for i <- 0..n do
      for j <- 0..m do
        cond do
          i == 0 -> j * gap_penalty
          j == 0 -> i * gap_penalty
          true -> 0
        end
      end
    end

    {matrix, n, m}
  end

  defp fill_matrix(matrix, seq1, seq2, match_score, mismatch_penalty, gap_penalty) do
    chars1 = String.graphemes(seq1)
    chars2 = String.graphemes(seq2)

    Enum.reduce(1..length(chars1), matrix, fn i, acc ->
      Enum.reduce(1..length(chars2), acc, fn j, row_acc ->
        char1 = Enum.at(chars1, i-1)
        char2 = Enum.at(chars2, j-1)

        # Вычисляем score для match/mismatch
        match_score_val = if char1 == char2, do: match_score, else: mismatch_penalty

        # Три варианта:
        diagonal = get_matrix_value(acc, i-1, j-1) + match_score_val
        up = get_matrix_value(acc, i-1, j) + gap_penalty
        left = get_matrix_value(acc, i, j-1) + gap_penalty

        # Берём максимальное значение
        max_score = Enum.max([diagonal, up, left])

        # Обновляем матрицу
        List.update_at(row_acc, i, fn row ->
          List.update_at(row, j, fn _ -> max_score end)
        end)
      end)
    end)
  end

  defp get_matrix_value(matrix, i, j) do
    if i >= 0 and j >= 0 do
      row = Enum.at(matrix, i, [])
      Enum.at(row, j, 0)
    else
      -1000  # Очень низкое значение для граничных случаев
    end
  end

  defp traceback(matrix, seq1, seq2, match_score, mismatch_penalty, gap_penalty) do
    chars1 = String.graphemes(seq1)
    chars2 = String.graphemes(seq2)
    n = length(chars1)
    m = length(chars2)

    # Начинаем с правого нижнего угла
    final_score = get_matrix_value(matrix, n, m)
    do_traceback(matrix, chars1, chars2, n, m, {"", "", final_score}, match_score, mismatch_penalty, gap_penalty)
  end

  defp do_traceback(matrix, chars1, chars2, i, j, {acc1, acc2, score}, match_score, mismatch_penalty, gap_penalty) when i > 0 and j > 0 do
    current_score = get_matrix_value(matrix, i, j)
    char1 = Enum.at(chars1, i-1)
    char2 = Enum.at(chars2, j-1)

    # Проверяем откуда пришли
    match_score_val = if char1 == char2, do: match_score, else: mismatch_penalty
    diagonal = get_matrix_value(matrix, i-1, j-1) + match_score_val
    up = get_matrix_value(matrix, i-1, j) + gap_penalty
    left = get_matrix_value(matrix, i, j-1) + gap_penalty

    cond do
      current_score == diagonal ->
        # Пришли по диагонали - match/mismatch
        do_traceback(matrix, chars1, chars2, i-1, j-1,
          {char1 <> acc1, char2 <> acc2, score},
          match_score, mismatch_penalty, gap_penalty)

      current_score == up ->
        # Пришли сверху - gap в seq2
        do_traceback(matrix, chars1, chars2, i-1, j,
          {char1 <> acc1, "-" <> acc2, score},
          match_score, mismatch_penalty, gap_penalty)

      current_score == left ->
        # Пришли слева - gap в seq1
        do_traceback(matrix, chars1, chars2, i, j-1,
          {"-" <> acc1, char2 <> acc2, score},
          match_score, mismatch_penalty, gap_penalty)

      true ->
        {acc1, acc2, score}
    end
  end

  defp do_traceback(_matrix, chars1, _chars2, i, 0, {acc1, acc2, score}, _match_score, _mismatch_penalty, _gap_penalty) when i > 0 do
    # Добавляем оставшиеся gaps в seq2
    remaining_chars = Enum.slice(chars1, 0..i-1) |> Enum.join()
    gaps = String.duplicate("-", i)
    {remaining_chars <> acc1, gaps <> acc2, score}
  end

  defp do_traceback(_matrix, _chars1, chars2, 0, j, {acc1, acc2, score}, _match_score, _mismatch_penalty, _gap_penalty) when j > 0 do
    # Добавляем оставшиеся gaps в seq1
    remaining_chars = Enum.slice(chars2, 0..j-1) |> Enum.join()
    gaps = String.duplicate("-", j)
    {gaps <> acc1, remaining_chars <> acc2, score}
  end

  defp do_traceback(_matrix, _chars1, _chars2, 0, 0, {acc1, acc2, score}, _match_score, _mismatch_penalty, _gap_penalty) do
    {acc1, acc2, score}
  end

  ## Smith-Waterman Implementation

  defp initialize_matrix_smith_waterman(seq1, seq2) do
    n = String.length(seq1)
    m = String.length(seq2)

    # Инициализируем нулями (в отличие от Needleman-Wunsch)
    matrix = for _i <- 0..n do
      for _j <- 0..m, do: 0
    end

    {matrix, n, m}
  end

  defp fill_matrix_smith_waterman(matrix, seq1, seq2, match_score, mismatch_penalty, gap_penalty) do
    chars1 = String.graphemes(seq1)
    chars2 = String.graphemes(seq2)

    Enum.reduce(1..length(chars1), matrix, fn i, acc ->
      Enum.reduce(1..length(chars2), acc, fn j, row_acc ->
        char1 = Enum.at(chars1, i-1)
        char2 = Enum.at(chars2, j-1)

        match_score_val = if char1 == char2, do: match_score, else: mismatch_penalty

        # Четыре варианта (добавили 0 для Smith-Waterman)
        diagonal = max(0, get_matrix_value(acc, i-1, j-1) + match_score_val)
        up = max(0, get_matrix_value(acc, i-1, j) + gap_penalty)
        left = max(0, get_matrix_value(acc, i, j-1) + gap_penalty)

        max_score = Enum.max([diagonal, up, left, 0])

        List.update_at(row_acc, i, fn row ->
          List.update_at(row, j, fn _ -> max_score end)
        end)
      end)
    end)
  end

  defp traceback_smith_waterman(matrix, seq1, seq2, match_score, mismatch_penalty, gap_penalty) do
    chars1 = String.graphemes(seq1)
    chars2 = String.graphemes(seq2)

    # Находим максимальное значение в матрице (не обязательно в углу!)
    {max_i, max_j, max_score} = find_max_score(matrix)

    do_traceback_smith_waterman(matrix, chars1, chars2, max_i, max_j, {"", "", max_score}, match_score, mismatch_penalty, gap_penalty)
  end

  defp find_max_score(matrix) do
    {max_i, max_j, max_val} =
      matrix
      |> Enum.with_index()
      |> Enum.flat_map(fn {row, i} ->
        Enum.with_index(row) |> Enum.map(fn {val, j} -> {i, j, val} end)
      end)
      |> Enum.max_by(fn {_i, _j, val} -> val end, fn -> {0, 0, 0} end)

    {max_i, max_j, max_val}
  end

  defp do_traceback_smith_waterman(matrix, chars1, chars2, i, j, {acc1, acc2, score}, match_score, mismatch_penalty, gap_penalty) when i > 0 and j > 0 do
    current_score = get_matrix_value(matrix, i, j)

    # Останавливаемся когда доходим до 0
    if current_score == 0 do
      {acc1, acc2, score}
    else
      char1 = Enum.at(chars1, i-1)
      char2 = Enum.at(chars2, j-1)

      diagonal = get_matrix_value(matrix, i-1, j-1)
      up = get_matrix_value(matrix, i-1, j)
      left = get_matrix_value(matrix, i, j-1)

      max_prev = Enum.max([diagonal, up, left])

      cond do
        max_prev == diagonal ->
          do_traceback_smith_waterman(matrix, chars1, chars2, i-1, j-1,
            {char1 <> acc1, char2 <> acc2, score},
            match_score, mismatch_penalty, gap_penalty)

        max_prev == up ->
          do_traceback_smith_waterman(matrix, chars1, chars2, i-1, j,
            {char1 <> acc1, "-" <> acc2, score},
            match_score, mismatch_penalty, gap_penalty)

        max_prev == left ->
          do_traceback_smith_waterman(matrix, chars1, chars2, i, j-1,
            {"-" <> acc1, char2 <> acc2, score},
            match_score, mismatch_penalty, gap_penalty)

        true ->
          {acc1, acc2, score}
      end
    end
  end

  defp do_traceback_smith_waterman(_matrix, _chars1, _chars2, _i, _j, {acc1, acc2, score}, _match_score, _mismatch_penalty, _gap_penalty) do
    {acc1, acc2, score}
  end

  ## Utility Functions

  defp calculate_identity(aligned1, aligned2) do
    aligned1_chars = String.graphemes(aligned1)
    aligned2_chars = String.graphemes(aligned2)

    {matches, total} =
      Enum.zip(aligned1_chars, aligned2_chars)
      |> Enum.reduce({0, 0}, fn {char1, char2}, {match_acc, total_acc} ->
        new_total = if char1 != "-" and char2 != "-", do: total_acc + 1, else: total_acc
        new_matches = if char1 == char2 and char1 != "-", do: match_acc + 1, else: match_acc
        {new_matches, new_total}
      end)

    if total > 0, do: matches / total, else: 0.0
  end

  # Публичная функция для форматирования процентов
  def format_percentage(value) do
    if is_float(value) do
      :erlang.float_to_binary(value * 100, [decimals: 1])
    else
      "0.0"
    end
  end
end

# Тестовые последовательности
test_sequences = [
  {"GATTACA", "GCATGCU"},
  {"ACGT", "ACGT"},           # Идентичные
  {"ACGT", "TGCA"},           # Полностью разные
  {"A", "A"},                 # Короткие
  {"GATTACA", "GATTACA"},     # Длинные идентичные
]

IO.puts("=== Needleman-Wunsch Global Alignment ===")
IO.puts("")

Enum.each(test_sequences, fn {seq1, seq2} ->
  result = SequenceAlignment.needleman_wunsch(seq1, seq2)

  IO.puts("Последовательность 1: #{seq1}")
  IO.puts("Последовательность 2: #{seq2}")
  IO.puts("Aligned 1: #{result.aligned_seq1}")
  IO.puts("Aligned 2: #{result.aligned_seq2}")
  IO.puts("Score: #{result.score}")
  IO.puts("Identity: #{SequenceAlignment.format_percentage(result.identity)}%")
  IO.puts("---")
end)

IO.puts("")
IO.puts("=== Smith-Waterman Local Alignment ===")
IO.puts("")

# Тесты для локального выравнивания
local_test_sequences = [
  {"GGTTGACTA", "TGTTACGG"},     # Имеют общую подпоследовательность
  {"GATTACA", "ATTA"},           # Одна является подстрокой другой
  {"ACGTACGT", "CGTA"},          # Локальное совпадение
]

Enum.each(local_test_sequences, fn {seq1, seq2} ->
  result = SequenceAlignment.smith_waterman(seq1, seq2)

  IO.puts("Последовательность 1: #{seq1}")
  IO.puts("Последовательность 2: #{seq2}")
  IO.puts("Aligned 1: #{result.aligned_seq1}")
  IO.puts("Aligned 2: #{result.aligned_seq2}")
  IO.puts("Score: #{result.score}")
  IO.puts("Identity: #{SequenceAlignment.format_percentage(result.identity)}%")
  IO.puts("---")
end)

# Сравнение двух алгоритмов на одном примере
IO.puts("")
IO.puts("=== Сравнение Global vs Local Alignment ===")

seq1 = "GGTTGACTA"
seq2 = "TGTTACGG"

global_result = SequenceAlignment.needleman_wunsch(seq1, seq2)
local_result = SequenceAlignment.smith_waterman(seq1, seq2)

IO.puts("Последовательность 1: #{seq1}")
IO.puts("Последовательность 2: #{seq2}")
IO.puts("")

IO.puts("Global Alignment (Needleman-Wunsch):")
IO.puts("Aligned 1: #{global_result.aligned_seq1}")
IO.puts("Aligned 2: #{global_result.aligned_seq2}")
IO.puts("Score: #{global_result.score}")
IO.puts("Identity: #{SequenceAlignment.format_percentage(global_result.identity)}%")
IO.puts("")

IO.puts("Local Alignment (Smith-Waterman):")
IO.puts("Aligned 1: #{local_result.aligned_seq1}")
IO.puts("Aligned 2: #{local_result.aligned_seq2}")
IO.puts("Score: #{local_result.score}")
IO.puts("Identity: #{SequenceAlignment.format_percentage(local_result.identity)}%")