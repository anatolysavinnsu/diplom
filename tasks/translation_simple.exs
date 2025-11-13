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

  def translate(dna) do
    dna
    |> String.upcase()
    |> String.codepoints()
    |> Enum.chunk_every(3)
    |> Enum.map(&translate_codon/1)
    |> Enum.join()
  end

  defp translate_codon(codon) when length(codon) == 3 do
    codon_str = Enum.join(codon)
    @genetic_code[codon_str] || "?"  # "?" для неизвестных кодонов
  end

  defp translate_codon(_incomplete), do: ""  # Пропускаем неполные кодоны
end

# Тест
dna_sequence = "ATGGCCATTGTAATGGGCCGCTGAAAGGGTGCCCGATAG"
protein = Translation.translate(dna_sequence)

IO.puts("DNA последовательность:")
IO.puts(dna_sequence)
IO.puts("\nБелковая последовательность:")
IO.puts(protein)