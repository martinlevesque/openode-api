module Remote
  module Dns
    # Base dns
    class Base
      def self.instance(type = 'vultr')
        config_path = CloudProvider::Manager.config_path
        config = CloudProvider::Manager.get_config(config_path)
        "Remote::Dns::#{type.capitalize}".constantize.new(config['application']['dns'])
      end

      def all_root_domains
        raise 'missing implementation'
      end

      def add_root_domain(_domain, _ip)
        raise 'missing implementation'
      end

      def add_root_domain_if_not_exists(root_domain, main_ip)
        add_root_domain(root_domain, main_ip) unless all_root_domains.include?(root_domain)
      end

      # return [ { name, type, value } ]
      def domain_records(_domain)
        raise 'missing implementation'
      end

      def add_record(_root_domain, _name, _type, _value, _priority)
        raise 'missing implementation'
      end

      # name.root_domain
      def get_name_from_domain_name(root_domain, domain_name)
        root_domain != domain_name ? domain_name.split(".#{root_domain}")[0] : ''
      end

      def add_domain_name_record(root_domain, domain_name, type, value, priority)
        name = get_name_from_domain_name(root_domain, domain_name)

        add_record(root_domain, name, type, value, priority)
      end

      def delete_record(_root_domain, _record)
        raise 'missing implementation'
      end

      def entries_match(entry1, entry2)
        entry1['domainName'] == entry2['domainName'] &&
          entry1['type'] == entry2['type'] &&
          entry1['value'] == entry2['value']
      end

      def dns_entry_exists?(root_domain, existing_records, dns_entry)
        existing_records.any? do |record|
          first_part_domain = record['name'] ? "#{record['name']}." : ''
          record_domain_name = "#{first_part_domain}#{root_domain}"
          record['domainName'] = record_domain_name

          entries_match(record, dns_entry)
        end
      end

      # deprecated entries - should be removed
      def dns_entry_deprecated?(root_domain, main_domain, existing_record, dns_entries)
        record = existing_record

        first_part_domain = record['name'] ? "#{record['name']}." : ''
        record_domain_name = "#{first_part_domain}#{root_domain}"
        record['domainName'] = record_domain_name

        if main_domain != root_domain && !record_domain_name.include?(main_domain)
          false
        else
          dns_entries.none? { |dns_entry| entries_match(dns_entry, record) }
        end
      end

      # returns the ones created, the ones deleted
      def update(root_domain, main_domain, dns_entries, main_ip)
        result = {
          created: [],
          deleted: []
        }

        add_root_domain_if_not_exists(root_domain, main_ip)

        records = domain_records(root_domain)

        # which records should we CREATE ?
        dns_entries.each do |dns_entry|
          next if dns_entry_exists?(root_domain, records, dns_entry)

          add_record(root_domain, dns_entry['name'],
                     dns_entry['type'], dns_entry['value'], dns_entry['priority'])
          result[:created] << dns_entry
        end

        records.each do |record|
          if dns_entry_deprecated?(root_domain, main_domain, record, dns_entries)
            delete_record(root_domain, record)
            result[:deleted] << record
          end
        end

        result
      end
    end
  end
end