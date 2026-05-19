import type { ThemeConfig } from 'antd'

const themeConfig: ThemeConfig = {
  token: {
    colorPrimary:         '#185FA5',
    colorPrimaryHover:    '#0C447C',
    colorBgLayout:        '#F5F5F3',
    colorBgContainer:     '#ffffff',
    colorBorder:          '#E2E2E2',
    colorText:            '#1A1A1A',
    colorTextSecondary:   '#4A4A4A',
    colorTextPlaceholder: '#888888',
    colorError:           '#A32D2D',
    colorSuccess:         '#3B6D11',
    colorWarning:         '#BA7517',
    colorLink:            '#185FA5',
    fontFamily:           "Inter, 'Segoe UI', system-ui, -apple-system, sans-serif",
    fontSize:             13,
    fontSizeSM:           12,
    borderRadius:         6,
    borderRadiusSM:       4,
    borderRadiusLG:       8,
    controlHeight:        32,
    controlHeightSM:      28,
    controlHeightLG:      40,
    boxShadow:            '0 1px 4px rgba(0,0,0,0.06)',
    boxShadowSecondary:   '0 1px 2px rgba(0,0,0,0.04)',
    lineWidth:            1,
    motionDurationSlow:   '0.15s',
    motionDurationMid:    '0.1s',
    motionDurationFast:   '0.08s',
  },
  components: {
    Layout: {
      headerBg: '#ffffff',
      bodyBg:   '#F5F5F3',
      siderBg:  '#ffffff',
    },
    Menu: {
      itemBg:            'transparent',
      itemSelectedBg:    '#185FA5',
      itemSelectedColor: '#ffffff',
      itemHoverBg:       '#E6F1FB',
      itemColor:         '#4A4A4A',
      itemHeight:        36,
      iconSize:          18,
    },
    Button: {
      borderRadius:      6,
      controlHeight:     32,
      contentFontSize:   13,
      contentFontSizeSM: 12,
    },
    Input: {
      borderRadius:      6,
      controlHeight:     32,
      activeBorderColor: '#185FA5',
      activeShadow:      '0 0 0 2px rgba(24,95,165,0.15)',
      errorActiveShadow: '0 0 0 2px rgba(163,45,45,0.15)',
    },
    Select: {
      borderRadius:     6,
      controlHeight:    32,
      optionSelectedBg: '#E6F1FB',
    },
    DatePicker: {
      borderRadius:      6,
      controlHeight:     32,
      activeBorderColor: '#185FA5',
    },
    Table: {
      headerBg:           '#F5F5F3',
      headerColor:        '#1A1A1A',
      headerSortActiveBg: '#E6F1FB',
      rowHoverBg:         '#E6F1FB',
      cellPaddingBlock:   8,
      cellPaddingInline:  12,
      fontSize:           12,
      headerSplitColor:   '#E2E2E2',
    },
    Card: {
      borderRadius: 8,
      paddingLG:    16,
    },
    Modal: {
      borderRadius: 8,
    },
    Tag: {
      borderRadius: 9999,
      fontSizeSM:   11,
    },
    Tooltip: {
      borderRadius: 6,
    },
    Badge: {
      borderRadius: 9999,
    },
  },
}

export default themeConfig
