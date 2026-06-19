namespace SpinRise.Reports.Common.Models;

/// <summary>
/// Division / company banner shown at the top of every report, sourced from PP_DIVMAS.
/// Shared because all three PR reports (and most others) print the same header.
/// </summary>
public sealed class CompanyHeader
{
    public string DivCode { get; set; } = "";
    public string DivName { get; set; } = "";
    public string? Address1 { get; set; }
    public string? Address2 { get; set; }
    public string? Address3 { get; set; }
    public string? City { get; set; }
    public string? Pincode { get; set; }

    /// <summary>Address lines joined into a single printable string.</summary>
    public string AddressBlock =>
        string.Join(", ",
            new[] { Address1, Address2, Address3, City, Pincode }
                .Where(part => !string.IsNullOrWhiteSpace(part)));
}
