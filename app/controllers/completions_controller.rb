class CompletionsController < ApplicationController
  def create
    @task = Task.find(params[:task_id])
    @task.completions.create!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.action(:refresh, "") }
      format.html { redirect_back fallback_location: root_path }
    end
  end
end
