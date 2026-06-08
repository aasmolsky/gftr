# frozen_string_literal: true

class SessionsController < ApplicationController
  def google_callback
    user = User.find_or_create_from_google(request.env['omniauth.auth'])
    reset_session
    session[:user_id] = user.id
    redirect_to root_path, notice: "Logged in successfully"
  end

  def failure
    redirect_to root_path, alert: "Authentication failed"
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Logged out"
  end
end
