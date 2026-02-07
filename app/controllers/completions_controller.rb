class CompletionsController < ApplicationController
  def create
    @task = Task.find(params[:task_id])
    @completion = @task.completions.create!

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end
end
