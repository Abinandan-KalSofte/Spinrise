import { useEffect, useState, useCallback } from 'react'
import { Form, Row, Col, DatePicker, Select, Input, Spin } from 'antd'
import dayjs, { type Dayjs } from 'dayjs'
import type { DepartmentOption, EmployeeOption, PrHeader, PrParameters, PrTypeOption, ScreenMode } from '../types'
import { getDepartments, getEmployees, getPrTypes } from '../api/prApi'
import { useAuthStore } from '@/features/auth/store/useAuthStore'

export interface PrHeaderFormValues {
  prDate:   Dayjs
  depCode:  string
  depName:  string
  reqName:  string
  section:  string
  iType:    string
  refNo:    string
  poGrp:    string
}

interface Props {
  mode:       ScreenMode
  parameters: PrParameters | null
  initialPr:  PrHeader | null
  form:       ReturnType<typeof Form.useForm>[0]
  pDate:      Dayjs
}

export default function PrHeaderForm({ mode, parameters, initialPr, form, pDate }: Props) {
  const user    = useAuthStore((s) => s.user)
  const divCode = user?.divCode ?? ''

  const [depts,   setDepts]   = useState<DepartmentOption[]>([])
  const [emps,    setEmps]    = useState<EmployeeOption[]>([])
  const [prTypes, setPrTypes] = useState<PrTypeOption[]>([])
  const [loading, setLoading] = useState(false)

  const [deptSearch, setDeptSearch] = useState('')
  const [empSearch,  setEmpSearch]  = useState('')

  const isReadOnly = mode === 'VIEW'
  const empCommon  = parameters?.empMasterComm ?? 'N'

  const loadDepts = useCallback(async (q: string) => {
    if (!divCode) return
    const data = await getDepartments(divCode, q || undefined)
    setDepts(data)
  }, [divCode])

  const loadEmps = useCallback(async (q: string) => {
    if (!divCode) return
    const data = await getEmployees(divCode, empCommon, q || undefined)
    setEmps(data)
  }, [divCode, empCommon])

  // Load lookups on mount
  useEffect(() => {
    setLoading(true)
    Promise.all([
      loadDepts(''),
      loadEmps(''),
      getPrTypes(mode === 'VIEW' ? false : true).then(setPrTypes),
    ]).finally(() => setLoading(false))
  }, [loadDepts, loadEmps, mode])

  // Debounced dept search
  useEffect(() => {
    const t = setTimeout(() => void loadDepts(deptSearch), 250)
    return () => clearTimeout(t)
  }, [deptSearch, loadDepts])

  // Debounced emp search
  useEffect(() => {
    const t = setTimeout(() => void loadEmps(empSearch), 250)
    return () => clearTimeout(t)
  }, [empSearch, loadEmps])

  // Populate form when PR loaded or mode changes
  useEffect(() => {
    if (mode === 'ADD') {
      form.resetFields()
      form.setFieldValue('prDate', pDate)
      if (parameters?.defaultPrType) form.setFieldValue('iType', parameters.defaultPrType)
    } else if (initialPr) {
      form.setFieldsValue({
        prDate:  dayjs(initialPr.prDate),
        depCode: initialPr.depCode,
        reqName: initialPr.reqName || undefined,
        section: initialPr.section,
        iType:   initialPr.iType || undefined,
        refNo:   initialPr.refNo,
        poGrp:   initialPr.poGrp || undefined,
      })
    }
  }, [mode, initialPr, form, pDate, parameters])

  const purTypeFlg = parameters?.purTypeFlg ?? 0
  const reqMandatory = purTypeFlg > 0

  const fieldStyle = isReadOnly
    ? { pointerEvents: 'none' as const, opacity: 0.7 }
    : {}

  return (
    <Spin spinning={loading} size="small">
      <Form form={form} layout="vertical" size="small">
        <Row gutter={12}>
          {/* PR Date */}
          <Col span={3}>
            <Form.Item
              name="prDate"
              label="PR Date"
              rules={[{ required: true, message: 'PR Date is required' }]}
            >
              <DatePicker
                format="DD/MM/YYYY"
                style={{ width: '100%', ...fieldStyle }}
                disabled={isReadOnly}
                disabledDate={(d) => d && d.isBefore(pDate, 'day')}
              />
            </Form.Item>
          </Col>

          {/* PR Number (read-only) */}
          <Col span={3}>
            <Form.Item label="PR Number">
              <Input
                value={initialPr?.prNo ? String(initialPr.prNo) : 'Auto'}
                readOnly
                style={{ background: '#F5F5F3', fontFamily: 'monospace', color: '#185FA5' }}
              />
            </Form.Item>
          </Col>

          {/* Department */}
          <Col span={5}>
            <Form.Item
              name="depCode"
              label="Department"
              rules={[{ required: true, message: 'Department Cannot be empty' }]}
            >
              <Select
                showSearch
                placeholder="Type code or name…"
                filterOption={false}
                onSearch={setDeptSearch}
                disabled={isReadOnly}
                style={fieldStyle}
                options={depts.map((d) => ({
                  value: d.depCode,
                  label: `${d.depCode} — ${d.depName}`,
                }))}
              />
            </Form.Item>
          </Col>

          {/* Requester */}
          <Col span={5}>
            <Form.Item
              name="reqName"
              label="Requested By"
              rules={reqMandatory ? [{ required: true, message: 'Requester Name Cannot be empty' }] : []}
            >
              <Select
                showSearch
                placeholder="Type name or code…"
                filterOption={false}
                onSearch={setEmpSearch}
                disabled={isReadOnly}
                style={fieldStyle}
                allowClear
                options={emps.map((e) => ({
                  value: e.empNo,
                  label: `${e.empNo} — ${e.empName}`,
                }))}
              />
            </Form.Item>
          </Col>

          {/* Section */}
          <Col span={3}>
            <Form.Item name="section" label="Section">
              <Input
                maxLength={20}
                disabled={isReadOnly}
                style={fieldStyle}
                placeholder="Sub-section"
              />
            </Form.Item>
          </Col>

          {/* PR Type */}
          <Col span={3}>
            <Form.Item
              name="iType"
              label="PR Type"
              rules={[{ required: !isReadOnly, message: 'PR Type is required' }]}
            >
              <Select
                disabled={isReadOnly}
                style={fieldStyle}
                options={prTypes.map((t) => ({ value: t.iType, label: t.iDesc }))}
                placeholder="Select type"
              />
            </Form.Item>
          </Col>

          {/* Reference No */}
          <Col span={3}>
            <Form.Item name="refNo" label="Reference No.">
              <Input
                maxLength={20}
                disabled={isReadOnly}
                style={{ ...fieldStyle, textTransform: 'uppercase' }}
                onChange={(e) => form.setFieldValue('refNo', e.target.value.toUpperCase())}
                placeholder="Internal ref"
              />
            </Form.Item>
          </Col>

          {/* Order Type / PO Group — visible only when PurTypeFlg = 1 */}
          {purTypeFlg > 0 && (
            <Col span={3}>
              <Form.Item
                name="poGrp"
                label="Order Type"
                rules={[{ required: !isReadOnly, message: 'Please Select Order Type' }]}
              >
                <Input
                  maxLength={5}
                  disabled={isReadOnly}
                  style={fieldStyle}
                />
              </Form.Item>
            </Col>
          )}
        </Row>
      </Form>
    </Spin>
  )
}
