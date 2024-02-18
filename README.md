# fluent-plugin-winevtx-xml-nxt

## Next-Gen Fluentd parser plugin to parse XML rendered Windows EventLogs

[Fluentd](https://www.fluentd.org/) plugin to parse XML rendered Windows Event Logs.

Updated to process all 'EventData' fields. Also update error/type checking to process more cleanly.

### Installation

### Configuration

```aconf
<parse>
  @type winevtx_xml_nxt
  parse_eventdata true
  system_prefix   "event"
  data_prefix     "eventData"
</parse>
```

#### config_param :parse_eventdata, :bool,   default: true

Do you want to parse event-specific data contained within the EVTX are 'EventData'?

#### config_param :system_prefix,   :string, default: "event"

Add a prefix to Field names found within EVTX-standard 'System'; useful for segregating field and identifying which came from the EVTX record

#### config_param :data_prefix,     :string, default: "eventData"

Add a prefix to field names found within 'EventData'
