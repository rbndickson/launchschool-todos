require 'sinatra'
require "sinatra/reloader" if development?
require 'sinatra/content_for'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  def list_complete?(list)
    todos_total(list) > 0 && todos_remaining(list) == 0
  end

  def list_class(list)
    'complete' if list_complete?(list)
  end

  def todos_total(list)
    list[:todos].size
  end

  def todos_remaining(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition do |list|
      list_complete?(list)
    end

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition do |todo|
      todo[:completed]
    end

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

get '/lists/new' do
  erb :new_list, layout: :layout
end

def error_for_list_name(name)
  if session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  elsif !(1..100).cover?(name.length)
    'List name must be between 1 and 100 characters.'
  end
end

post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: params[:list_name], todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

def load_list(index)
  list = session[:lists][index] if index
  return list if list

  session[:error] = "The list you requested was not found."
  redirect "/lists"
  halt
end

get '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  erb :list, layout: :layout
end

get '/lists/:list_id/edit' do
  list_id = params[:list_id].to_i
  @list = load_list(list_id)

  erb :edit_list, layout: :layout
end

post '/lists/:list_id' do
  list_name = params[:list_name].strip
  list_id = params[:list_id].to_i
  @list = load_list(list_id)

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list has been updated.'
    redirect "/lists/#{list_id}"
  end
end

post '/lists/:list_id/destroy' do
  list_id = params[:list_id].to_i
  session[:lists].delete_at(list_id)
  session[:success] = 'The list has been deleted.'
  redirect "/lists"
end

def error_for_todo(name)
  if !(1..100).cover?(name.length)
    'Todo must be between 1 and 100 characters.'
  end
end

post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: text, completed: false }
    session[:success] = 'The todo was added.'
    redirect "/lists/#{@list_id}"
  end
end

post '/lists/:list_id/todos/:todo_id/destroy' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  @list[:todos].delete_at(todo_id)
  session[:success] = 'The todo has been deleted.'
  redirect "/lists/#{@list_id}"
end

post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'
  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = 'The todo has been updated.'
  redirect "/lists/#{@list_id}"
end

post '/lists/:list_id/complete_all' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = 'All todos have been completed.'
  redirect "/lists/#{@list_id}"
end
