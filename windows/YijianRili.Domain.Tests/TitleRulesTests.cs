using YijianRili.Domain.Services;

namespace YijianRili.Domain.Tests;

public class TitleRulesTests
{
    [Fact]
    public void Validate_EmptyAndTooLong()
    {
        Assert.Equal(TitleValidationResult.Empty, TitleRules.Validate("  "));
        Assert.Equal(TitleValidationResult.TooLong, TitleRules.Validate(new string('x', 101)));
        Assert.Equal(TitleValidationResult.Ok, TitleRules.Validate("ok"));
    }
}
