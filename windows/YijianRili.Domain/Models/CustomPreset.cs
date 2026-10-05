namespace YijianRili.Domain.Models;

public sealed class CustomPreset
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public required string Name { get; init; }
    public required IReadOnlyList<int> Intervals { get; init; }
}
