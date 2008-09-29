ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.
  
  # Sample of regular route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action
  map.connect 'recover/:r_session', :controller => 'people', :action => 'recover'
  map.connect 'proposals/:id', :controller => 'proposals', :action => 'show'
  map.connect('proposals/by_author/:author_id', 
              :controller => 'proposals', 
              :action => 'by_author')
  map.connect('proposals/:id/:document_id', 
              :controller => 'proposals',
              :action => 'get_document')

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
  map.connect('/sys_conf_adm/add_catalog_row/:catalog',
              :controller => 'sys_conf_adm',
              :action => 'add_catalog_row')

  # Sample of named route:
  # map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # You can have the root of your site routed by hooking up '' 
  # -- just remember to delete public/index.html.
  map.connect '', :controller => "conferences"

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  map.connect ':controller/service.wsdl', :action => 'wsdl'

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'
end
