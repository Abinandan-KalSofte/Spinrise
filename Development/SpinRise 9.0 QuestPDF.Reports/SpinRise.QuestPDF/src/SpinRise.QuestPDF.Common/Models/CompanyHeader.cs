namespace SpinRise.QuestPDF.Common.Models;

/// <summary>
/// Division / company banner data sourced from <c>PP_DIVMAS</c>.
/// </summary>
public sealed class CompanyHeader
{
    public string  DivCode  { get; set; } = "";
    public string  DivName  { get; set; } = "";
    public string? Address1 { get; set; }
    public string? Address2 { get; set; }
    public string? Address3 { get; set; }
    public string? City     { get; set; }
    public string? Pincode  { get; set; }
}
