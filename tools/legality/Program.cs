// Copyright (c) 2026 Roxas2712. SPDX-License-Identifier: GPL-3.0-or-later
// Isolated process boundary: the engine does not load or link this assembly.
using System.Text.Json;
using PKHeX.Core;

try
{
    var line = Console.In.ReadToEnd();
    if (line.Length > 65536) throw new InvalidDataException("Legality request is too large");
    using var doc = JsonDocument.Parse(line, new JsonDocumentOptions { MaxDepth = 12 });
    var root = doc.RootElement;
    if (root.GetProperty("schema").GetInt32() != 1) throw new InvalidDataException("Unsupported schema");
    var generation = root.GetProperty("generation").GetInt32();
    var bytes = Convert.FromBase64String(root.GetProperty("pkm").GetString()!);
    var ot = root.TryGetProperty("ot", out var o) ? Convert.FromBase64String(o.GetString()!) : [];
    var nickname = root.TryGetProperty("nickname", out var n) ? Convert.FromBase64String(n.GetString()!) : [];
    var expected = generation switch { 1 => 44, 2 => 48, 3 => 80, 4 or 5 => 136, _ => throw new InvalidDataException("Unsupported generation") };
    if (bytes.Length != expected || (generation <= 2 && (ot.Length != 11 || nickname.Length != 11))) throw new InvalidDataException("Invalid native record length");
    PKM mon = generation switch
    {
        1 => new PK1(bytes, ot, nickname),
        2 => new PK2(bytes, ot, nickname),
        3 => new PK3(bytes),
        4 => new PK4(bytes),
        5 => new PK5(bytes),
        _ => throw new InvalidDataException("Unsupported format"),
    };
    var analysis = new LegalityAnalysis(mon);
    var result = new
    {
        schema = 1, engine = "PKHeX.Core/26.10.18", parsed = analysis.Parsed, valid = analysis.Parsed && analysis.Valid,
        dex = mon.Species, generation, checksum = mon.ChecksumValid,
        checks = analysis.Results.Select(c => new { valid = c.Valid, group = c.Identifier.ToString(), code = c.Result.ToString(), severity = c.Judgement.ToString() }).ToArray(),
        moves = analysis.Info.Moves.Select(m => new { valid = m.Valid }).ToArray(),
        encounter = new { species = analysis.EncounterOriginal.Species, generation = analysis.EncounterOriginal.Generation },
    };
    Console.WriteLine(JsonSerializer.Serialize(result));
}
catch (Exception)
{
    // Do not echo uploaded bytes, trainer names or local paths into logs.
    Console.WriteLine("{\"schema\":1,\"parsed\":false,\"valid\":false,\"error\":\"Malformed or unsupported native record\"}");
    Environment.ExitCode = 2;
}
