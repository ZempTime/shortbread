Rails.application.routes.draw do
  get "owner/bootstrap", to: "owner_bootstraps#show"
  post "owner/bootstrap/options", to: "owner_bootstraps#options"
  post "owner/bootstrap", to: "owner_bootstraps#create"

  get "invitations/:locator", to: "invitation_previews#show"
  post "invitations/:locator/accept", to: "invitation_acceptances#create"
  post "_shortbread/session", to: "site_sessions#create"
  get "/", to: "site_contents#show"

  namespace :api do
    namespace :v1 do
      resources :sites, only: :create, param: :slug do
        resources :publish_plans, only: :create, path: "publish-plans"
        resources :releases, only: :index, param: :number do
          post :rollback, on: :member, controller: "release_rollbacks", action: :create
        end
      end
      resources :people, only: :create
      resources :grants, only: :create do
        resources :invitations, only: :create
      end
      put "publish-plans/:publish_plan_id/blobs/:sha256", to: "publish_plan_blobs#update"
      post "publish-plans/:id/finalize", to: "publish_plan_finalizations#create"
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  apex_host = ENV.fetch("SHORTBREAD_APEX_HOST", "localhost")
  constraints ->(request) { request.host == apex_host } do
    get "up" => "rails/health#show", as: :rails_health_check
  end
  get "up", to: ->(_environment) { Shortbread::RackResponses.not_found }
end
