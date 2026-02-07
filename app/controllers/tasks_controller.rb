class TasksController < ApplicationController
  before_action :set_room
  before_action :set_task, only: %i[edit update destroy]

  def index
    @tasks = @room.tasks.includes(:completions).sort_by(&:health_score)
  end

  def new
    @task = @room.tasks.build
  end

  def create
    @task = @room.tasks.build(task_params)
    if @task.save
      redirect_to rooms_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @task.update(task_params)
      redirect_to rooms_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy
    redirect_to rooms_path
  end

  private

  def set_room
    @room = Room.find(params[:room_id])
  end

  def set_task
    @task = @room.tasks.find(params[:id])
  end

  def task_params
    params.expect(task: [ :name, :decay_period_days ])
  end
end
