using System.Data;
using Dapper;

namespace Spinrise.Infrastructure.Data;

public class DateOnlyTypeHandler : SqlMapper.TypeHandler<DateOnly>
{
    public override void SetValue(IDbDataParameter parameter, DateOnly value)
    {
        parameter.Value = value.ToDateTime(TimeOnly.MinValue);
        parameter.DbType = DbType.Date;
    }

    public override DateOnly Parse(object value) =>
        value is DateTime dt ? DateOnly.FromDateTime(dt) : DateOnly.Parse(value.ToString()!);
}
