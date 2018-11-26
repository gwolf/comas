ActionController::Routing::Routes.draw do |map|
  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
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
  map.connect('attendance_adm/list/:conference_id.xls',
              :controller => 'attendance_adm',
              :action => 'xls_list')
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
  map.connect('v/:conference_id/:person_id',
              :controller => 'certificates', :action => 'verif')

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

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

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller

  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing or commenting them out if you're using named routes and resources.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
