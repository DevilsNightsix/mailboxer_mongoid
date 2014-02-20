module MailboxerMongoid
  module MongoidExt
    module Factory

      def from_db(klass, attributes = nil, selected_fields = nil)
        type = (attributes || {})["_type"]
        if type.blank?
          klass.instantiate(attributes, selected_fields)
        else
          if klass.respond_to?(:is_proxy_for) && klass.is_proxy_for(type.camelize.constantize)
            klass.instantiate(attributes, selected_fields)
          else
            type.camelize.constantize.instantiate(attributes, selected_fields)
          end
        end
      end

    end
  end
end
