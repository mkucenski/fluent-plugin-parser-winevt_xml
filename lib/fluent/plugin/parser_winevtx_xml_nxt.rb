require 'fluent/plugin/parser'
require 'nokogiri'

module Fluent::Plugin
  class WinevtXMLparser < Fluent::Plugin::Parser
    Fluent::Plugin.register_parser("winevtx_xml_nxt", self)

    config_param :parse_eventdata, :bool,   default: true
    config_param :system_prefix,   :string, default: "event"
    config_param :data_prefix,     :string, default: "eventData"

    def configure(conf)
      super

      #      Sample:2024-02-16T18:07:30.284917000Z
      @time_format = "%Y-%m-%dT%H:%M:%S.%NZ"
      @time_parser = Fluent::TimeParser.new(@time_format, false, "UTC")
    end

    def event_id(eventid_str, qualifiers_str = nil)
      #log.debug("WinevtXMLparser::event_id() " + eventid_str + ", " + qualifiers_str.to_s)

      if eventid_str
        if qualifiers_str
          return ((eventid_str.to_i & 0xffff) | (qualifiers_str.to_i & 0xffff) << 16).to_s
        else
          return eventid_str
        end
      else
        log.error("WinevtXMLparser::event_id() Invalid eventid_str")
      end
    end

    def event_element(xml_nodeset, element_name, element_attribute_name = nil)
      #log.debug("WinevtXMLparser::event_element() " + element_name + ", " + element_attribute_name.to_s)

      element_node = (xml_nodeset/element_name)
      # Only proceed if we're able to access the element w/in the XML node
      if element_node
        # If an attribute is given to this function, return it, otherwise return
        # the .text of this node
        if element_attribute_name
          element_attribute = element_node.attribute(element_attribute_name)
          if element_attribute
            # Drop "blank" entries containing only a '-'
            if element_attribute.text != "-" then element_attribute.text else nil end
          end
        else
            # Drop "blank" entries containing only a '-'
          if element_node.text != "-" then element_node.text else nil end
        end
      else
        log.error("WinevtXMLparser::event_element() Invalid element_node")
      end
    end

    def prefix(name:, system:false, data:false)
      if system
        return @system_prefix + name
      end
      if data
        return @data_prefix + name
      end
      return name
    end

    def event_level(level)
      # Translate the numeric Level string into the correct readable string; if
      # unavailable, revert to the numeric value
      case level
        when "0"
          "LogAlways"
        when "1"
          "Critical"
        when "2"
          "Error"
        when "3"
          "Warning"
        when "4"
          "Verbose"
        when "5"
          "Informational"
        else
          level
      end
    end

    def parse(text)
      #log.debug("WinevtXMLparser::parse()")

      record = {}
      xml_doc = Nokogiri::XML(text)

      system_xml_nodeset = xml_doc/'Event'/'System'
      if system_xml_nodeset
        # Extract values to calculate EventID based on Qualifiers
        eventID = event_element(system_xml_nodeset, "EventID")
        eventRawID = nil
        eventRawQualifier = event_element(system_xml_nodeset, "EventID", "Qualifiers")
        if eventRawQualifier
          eventRawID = eventID
          eventID = event_id(eventRawID, eventRawQualifier)
        end

        # Extract other values for a brief summary 'message' and timestamp
        eventSource  = event_element(system_xml_nodeset, "Provider", "Name")
        eventLevel   = event_level(event_element(system_xml_nodeset, "Level"))
        eventTask    = event_element(system_xml_nodeset, "Task")
        eventChannel = event_element(system_xml_nodeset, "Channel")
        eventTime    = event_element(system_xml_nodeset, "TimeCreated", "SystemTime")

        # Store all values as the record hash
        record[prefix(name:"ID", system:true)]                           = eventID
        record[prefix(name:"RawID", system:true)]                        = eventRawID
        record[prefix(name:"RawQualifier", system:true)]                 = eventRawQualifier
        record[prefix(name:"ProviderName", system:true)]                 = eventSource
        record[prefix(name:"ProviderGUID", system:true)]                 = event_element(system_xml_nodeset, "Provider", "Guid")
        record[prefix(name:"ProviderEventSourceName", system:true)]      = event_element(system_xml_nodeset, "Provider", "EventSourceName")
        record[prefix(name:"Level", system:true)]                        = eventLevel
        record[prefix(name:"Task", system:true)]                         = eventTask
        record[prefix(name:"Opcode", system:true)]                       = event_element(system_xml_nodeset, "Opcode")
        record[prefix(name:"Keywords", system:true)]                     = event_element(system_xml_nodeset, "Keywords")
        record[prefix(name:"TimeCreated", system:true)]                  = eventTime
        record[prefix(name:"RecordID", system:true)]                     = event_element(system_xml_nodeset, "EventRecordID")
        record[prefix(name:"CorrelationActivityID", system:true)]        = event_element(system_xml_nodeset, "Correlation", "ActivityID")
        record[prefix(name:"CorrelationRelatedActivityID", system:true)] = event_element(system_xml_nodeset, "Correlation", "RelatedActivityID")
        record[prefix(name:"ExecutionThreadID", system:true)]            = event_element(system_xml_nodeset, "Execution", "ThreadID")
        record[prefix(name:"ExecutionProcessID", system:true)]           = event_element(system_xml_nodeset, "Execution", "ProcessID")
        record[prefix(name:"Channel", system:true)]                      = eventChannel
        record[prefix(name:"Computer", system:true)]                     = event_element(system_xml_nodeset, "Computer")
        record[prefix(name:"SecurityUserID", system:true)]               = event_element(system_xml_nodeset, "Security", "UserID")
        record[prefix(name:"Version", system:true)]                      = event_element(system_xml_nodeset, "Version")

        # Store a brief summary 'message' for the output record
        record["message"] = eventLevel + ": " + eventSource + " (" + eventChannel + ") EventID=" + eventID + " Task=" + eventTask

        # Extract 'EventData' sub-fields unique to each event-type
        if @parse_eventdata
          eventdata_xml_nodeset = xml_doc/'Event'/'EventData'
          if eventdata_xml_nodeset
            # Loop through each child of the 'EventData' NodeSet
            eventdata_xml_nodeset.children.each do |element|
              element_name_attribute = element.attribute("Name")
              if element_name_attribute
                # Drop "blank" entries containing only a '-'
                if element.text != "-" 
                  # Record each 'Data' value by it's 'Name' attribute
                  record[prefix(name:element_name_attribute.text, data:true)] = element.text
                end
              else
                log.error("WinevtXMLparser::parse() Invalid 'Name' element_name_attribute")
              end
            end
          else
            log.error("WinevtXMLparser::parse() Unable to Parse XML: 'Event/EventData'")
          end
        end
  
        # Parse 'TimeCreated/SystemTime for this record's timestamp.
        time = @time_parser.parse(eventTime)
        if !time
          # If parsing failes, use 'now' as the record timestamp
          log.warn("WinevtXMLparser::parse() Unable to parse 'TimeCreated/SystemTime'; using 'Fluent::EventTime.now' instead.")
          time = Fluent::EventTime.now
        end

        yield time, record
      else
        log.error("WinevtXMLparser::parse() Unable to Parse XML: 'Event/System'")
      end
    end
  end
end
