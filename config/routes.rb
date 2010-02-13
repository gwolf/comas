ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action
  map.connect 'recover/:r_session', :controller => 'people', :action => 'recover'

  map.connect('proposals/by_author/:author_id', 
              :controller => 'proposals', 
              :action => 'by_author')
  map.connect('proposals/:id/doc/:document_id', 
              :controller => 'proposals',
              :action => 'get_document')
  map.connect('proposals/:conference_id/new',
              :controller => 'proposals',
              :action => 'new')

  map.connect('sys_conf_adm/list_conferences_fields',
              :controller => 'sys_conf_adm',
              :action => 'list_table_fields',
              :table => 'conferences')
  map.connect('sys_conf_adm/list_proposals_fields',
              :controller => 'sys_conf_adm',
              :action => 'list_table_fields',
              :table => 'proposals')
  map.connect('sys_conf_adm/list_people_fields',
              :controller => 'sys_conf_adm',
              :action => 'list_table_fields',
              :table => 'people')

  map.connect('sys_conf_adm/show_catalog/:catalog',
              :controller => 'sys_conf_adm',
              :action => 'show_catalog')
  map.connect('sys_conf_adm/delete_catalog_row/:catalog/:id',
              :controller => 'sys_conf_adm',
              :action => 'delete_catalog_row')
  map.connect('sys_conf_adm/add_catalog_row/:catalog',
              :controller => 'sys_conf_adm',
              :action => 'add_catalog_row')
  map.connect('sys_conf_adm/edit/:key',
              :controller => 'sys_conf_adm', :action => 'edit')
  map.connect('sys_conf_adm/update/:key',
              :controller => 'sys_conf_adm', :action => 'update')

  map.connect('attendance_adm/list/:conference_id',
              :controller => 'attendance_adm',
              :action => 'list')
  map.connect('attendance_adm/att_by_tslot/:conference_id/:timeslot_id',
              :controller => 'attendance_adm',
              :action => 'att_by_tslot')
  map.connect('attendance_adm/for_person/:conference_id/:person_id',
              :controller => 'attendance_adm',
              :action => 'for_person')

  map.connect('photo/:id',
              :controller => 'people', :action => 'get_photo')
  map.connect('photo/:id',
              :controller => 'people', :action => 'get_photo',
              :size => 'normal')
  map.connect('thumb/:id',
              :controller => 'people', :action => 'get_photo',
              :size => 'thumb')
  
  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  map.connect '', :controller => "conferences"

  map.connect(':short_name',
              :controller => 'conferences',
              :action => 'show')

  map.connect('conferences.rss',
              :controller => 'conferences',
              :action => 'list',
              :format => 'rss')

  map.connect('invite/:invite',
              :controller => 'people',
              :action => 'claim_invite')

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'
end
