namespace Spinrise.Shared.Utilities;

public static class AmountToWords
{
    private static readonly string[] _units =
    {
        "", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE",
        "TEN", "ELEVEN", "TWELVE", "THIRTEEN", "FOURTEEN", "FIFTEEN", "SIXTEEN",
        "SEVENTEEN", "EIGHTEEN", "NINETEEN"
    };

    private static readonly string[] _tens =
        { "", "", "TWENTY", "THIRTY", "FORTY", "FIFTY", "SIXTY", "SEVENTY", "EIGHTY", "NINETY" };

    public static string Convert(decimal amount, string currency = "INR")
    {
        var intPart = (long)Math.Floor(amount);
        var decPart = (int)Math.Round((amount - (decimal)intPart) * 100);

        if (intPart == 0 && decPart == 0)
            return $"{currency} . ZERO ONLY";

        var words = intPart > 0 ? Words(intPart) : "";
        if (decPart > 0)
            words += (words.Length > 0 ? " AND " : "") + Words(decPart) + " PAISE";

        return $"{currency} . {words} ONLY";
    }

    private static string Words(long n)
    {
        if (n == 0)  return "";
        if (n < 20)  return _units[n];
        if (n < 100) return _tens[n / 10] + (n % 10 != 0 ? " " + _units[n % 10] : "");

        if (n < 1_000)
            return _units[n / 100] + " HUNDRED" + (n % 100 != 0 ? " " + Words(n % 100) : "");

        if (n < 100_000)
            return Words(n / 1_000) + " THOUSAND" + (n % 1_000 != 0 ? " " + Words(n % 1_000) : "");

        if (n < 10_000_000)
            return Words(n / 100_000) + " LAKH" + (n % 100_000 != 0 ? " " + Words(n % 100_000) : "");

        return Words(n / 10_000_000) + " CRORE" + (n % 10_000_000 != 0 ? " " + Words(n % 10_000_000) : "");
    }
}
