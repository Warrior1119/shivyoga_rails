FactoryBot.define do
  factory(:report_master) do
    deleted_at nil
    final_block "proc do |sub_task, ids, opts = {}|\n\n      raise ArgumentError.new('Sub task can not be blank.') unless sub_task.present?\n\n      if opts[:report_master_field_association_ids].present?\n        report_field_ass = ReportMasterFieldAssociation.where(:id => opts[:report_master_field_association_ids]).sort_by(&:id)\n      else\n        report_field_ass = ReportMasterFieldAssociation.where(:report_master_id => opts[:report_master_id]).sort_by(&:id)\n      end\n\n      header = report_field_ass.collect{|rfa| rfa.report_master_field.field_name.upcase}\n      rows = []\n\n      includable_data = [{:sadhak_profile => [{ :address => [:db_city, :db_state, :db_country] }, {:medical_practitioners_profile => [:medical_practitioner_speciality_area]}]}, {:event_order => [:registration_center_user, :registration_center, :event_registrations, :versions]}, {:event_order_line_item => [:versions]}, :event_seating_category_association, :seating_category, :user, :versions, {:event => [:event_seating_category_associations, :seating_categories, { :address => [:db_city, :db_state, :db_country] }, {:registration_centers => [:registration_center_users]}, :event_tax_type_associations, :tax_types]}, {:sy_club_member => [:sy_club]}]\n\n      event_registrations = EventRegistration.where(:id => ids).includes(includable_data)\n\n      is_exposed = sub_task.parent_task.taskable.try(:super_admin?)\n\n      event_registrations.each_with_index do |_registration, _index|\n        row = []\n        report_field_ass.each do |_report_field_ass|\n          block = eval(_report_field_ass.proc_block.to_s)\n          row.push(block.present? ? block.call(_registration, is_exposed) : nil)\n        end\n        rows.push(row)\n      end\n\n      file = GenerateExcel.generate({:rows => rows, :header => header, :data_type => 'file'})\n\n      sub_task.result = {:file => file, :from => event_registrations.first.id, :to => event_registrations.last.id, :format => 'xls'}\n    end"
    report_name "event_registration"
    required_params ["event_id"]
    start_block "proc do |parent_task, params = {}|\n\n      raise ArgumentError.new('Parent task can not be blank.') unless parent_task.present?\n\n      event = Event.preloaded_data.find_by_id(params[:event_id])\n\n      raise 'Event can not be blank.' unless event.present?\n\n      # Assign default value to from and to\n      from = params[:from].present? ? params[:from] : (Date.today - 10.years).to_s\n      to = params[:to].present? ? params[:to] : (Date.today + 10.years).to_s\n\n      if event.sy_event_company_id.present?\n        event_registrations = EventRegistration.where(:event_id => event.id, :status => (EventRegistration.valid_registration_statuses + EventRegistration.statuses.slice('cancelled', 'cancelled_refunded').values)).where('created_at >= ? AND created_at <= ?', from, to).order('serial_number')\n      else\n        event_registrations = EventRegistration.where(:event_id => event.id, :status => (EventRegistration.valid_registration_statuses + EventRegistration.statuses.slice('cancelled', 'cancelled_refunded').values)).where('created_at >= ? AND created_at <= ?', from, to).order('event_order_line_item_id')\n      end\n\n      if params[:report_master_field_association_ids].present?\n        report_field_ass = ReportMasterFieldAssociation.where(:id => params[:report_master_field_association_ids])\n      else\n        report_field_ass = ReportMasterFieldAssociation.where(:report_master_id => params[:report_master_id])\n      end\n      params[:batch_size] = (3e6 / (report_field_ass.size * 16)).to_i\n\n      # Update file name in parent task config\n      t_config = ActiveSupport::HashWithIndifferentAccess.new(parent_task.t_config)\n\n      t_config[:file_name] = event.try(:event_name).truncate(40, :omission => '... (continued)') + '_' + t_config[:file_name]\n\n      parent_task.update_columns(:t_config => t_config.to_json)\n\n      parent_task.result = event_registrations.pluck(:id)\n    end"
  end
end