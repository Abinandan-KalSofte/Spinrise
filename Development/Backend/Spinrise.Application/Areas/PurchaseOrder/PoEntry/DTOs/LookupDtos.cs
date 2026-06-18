namespace Spinrise.Application.Areas.PurchaseOrder.PoEntry.DTOs;

public class SupplierOptionDto
{
    public string SlCode       { get; set; } = "";
    public string SlName       { get; set; } = "";
    public string GstinNo      { get; set; } = "";
    public string GstStateCode { get; set; } = "";
    public string GstStateName { get; set; } = "";
    public string City         { get; set; } = "";   // CR-003
}

public class OrderTypeOptionDto
{
    public string PoGrp    { get; set; } = "";
    public string TypName  { get; set; } = "";
}

public class CarrierOptionDto
{
    public string CarCode  { get; set; } = "";
    public string CarName  { get; set; } = "";
}

public class BankOptionDto
{
    public string BankCode { get; set; } = "";
    public string BankName { get; set; } = "";
}

public class FormTypeOptionDto
{
    public string FormCode { get; set; } = "";
    public string FormName { get; set; } = "";
}

public class GstTaxCodeOptionDto
{
    public string TaxCode   { get; set; } = "";
    public string TaxDesc   { get; set; } = "";
    public decimal CgstPer  { get; set; }
    public decimal SgstPer  { get; set; }
    public decimal IgstPer  { get; set; }
    public string TaxStatus { get; set; } = "";
}

public class GstRoutingResultDto
{
    public string Route        { get; set; } = "LOCAL";
    public string DivStateCode { get; set; } = "";
    public string SupStateCode { get; set; } = "";
}

public class AddressOptionDto
{
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
}

public class CurrencyOptionDto
{
    public string  CurrCode { get; set; } = "";
    public string  CurrName { get; set; } = "";
    public decimal CurrRate { get; set; }
}
