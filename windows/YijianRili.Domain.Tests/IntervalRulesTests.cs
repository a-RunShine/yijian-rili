using YijianRili.Domain.Services;

namespace YijianRili.Domain.Tests;

public class IntervalRulesTests
{
    [Theory]
    [InlineData(new[] { 1, 3, 7 }, true)]
    [InlineData(new[] { 3, 7, 30 }, true)]
    [InlineData(new[] { 7 }, true)]
    [InlineData(new[] { 1, 2, 4, 7, 15 }, true)]
    [InlineData(new[] { 1, 365 }, true)]
    [InlineData(new[] { 0, 3, 7 }, false)]
    [InlineData(new[] { 3, -1, 7 }, false)]
    [InlineData(new int[0], false)]
    [InlineData(new[] { 1, 366 }, false)]
    [InlineData(new[] { 30, 7, 3 }, false)]
    [InlineData(new[] { 7, 7, 30 }, false)]
    public void Validate_MatchesMacBehavior(int[] intervals, bool expected)
        => Assert.Equal(expected, IntervalRules.Validate(intervals));

    [Fact]
    public void Validate_MaxTenIntervals()
    {
        Assert.True(IntervalRules.Validate(new[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }));
        Assert.False(IntervalRules.Validate(new[] { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }));
    }
}
