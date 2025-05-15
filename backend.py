from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import mysql.connector
import os
import json
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__, static_folder='static')
CORS(app)  # Enable CORS for all routes

# In-memory storage for user accounts (in a production app, use a database)
users = {}
next_user_id = 1

# Endpoint to serve the frontend
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def serve(path):
    if path != "" and os.path.exists(app.static_folder + '/' + path):
        return send_from_directory(app.static_folder, path)
    else:
        return send_from_directory(app.static_folder, 'index.html')

# Database connection endpoint
@app.route('/api/database/connect', methods=['POST'])
def connect_database():
    data = request.json
    host = data.get('host')
    port = data.get('port')
    user = data.get('user')
    password = data.get('password')
    database = data.get('database')
    
    try:
        # Attempt to establish a connection
        connection = mysql.connector.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            database=database
        )
        
        if connection.is_connected():
            connection.close()
            return jsonify({
                'success': True,
                'message': 'Connected successfully'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Connection failed: {str(e)}'
        }), 400
    
    return jsonify({
        'success': False,
        'message': 'Unknown error occurred'
    }), 500

# Get database tables
@app.route('/api/database/tables', methods=['POST'])
def get_tables():
    data = request.json
    connection_data = get_connection_from_request(data)
    
    if not connection_data:
        return jsonify({
            'success': False,
            'message': 'Invalid connection information'
        }), 400
    
    try:
        connection = create_connection(connection_data)
        cursor = connection.cursor()
        
        # Get list of tables in the database
        cursor.execute("SHOW TABLES")
        tables = [table[0] for table in cursor.fetchall()]
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'tables': tables
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Failed to fetch tables: {str(e)}'
        }), 400

# Get table data
@app.route('/api/database/table/data', methods=['POST'])
def get_table_data():
    data = request.json
    connection_data = get_connection_from_request(data)
    table_name = data.get('tableName')
    
    if not connection_data or not table_name:
        return jsonify({
            'success': False,
            'message': 'Invalid request parameters'
        }), 400
    
    try:
        connection = create_connection(connection_data)
        cursor = connection.cursor(dictionary=True)
        
        # Get table data with limit to prevent loading too much data
        cursor.execute(f"SELECT * FROM `{table_name}` LIMIT 100")
        rows = cursor.fetchall()
        
        # Convert any non-serializable objects to strings
        for row in rows:
            for key, value in row.items():
                if not isinstance(value, (str, int, float, bool, type(None))):
                    row[key] = str(value)
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': rows
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Failed to fetch table data: {str(e)}'
        }), 400

# Execute custom SQL query
@app.route('/api/database/execute', methods=['POST'])
def execute_query():
    data = request.json
    connection_data = get_connection_from_request(data)
    query = data.get('query')
    
    if not connection_data or not query:
        return jsonify({
            'success': False,
            'message': 'Invalid request parameters'
        }), 400
    
    try:
        connection = create_connection(connection_data)
        cursor = connection.cursor(dictionary=True)
        
        cursor.execute(query)
        
        # If the query is a SELECT statement, return the results
        if query.strip().upper().startswith('SELECT'):
            rows = cursor.fetchall()
            
            # Convert any non-serializable objects to strings
            for row in rows:
                for key, value in row.items():
                    if not isinstance(value, (str, int, float, bool, type(None))):
                        row[key] = str(value)
            
            result = {
                'success': True,
                'results': rows,
                'rowCount': len(rows)
            }
        else:
            # For non-SELECT queries, return affected row count
            connection.commit()
            result = {
                'success': True,
                'affectedRows': cursor.rowcount,
                'results': []
            }
        
        cursor.close()
        connection.close()
        
        return jsonify(result)
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Query execution failed: {str(e)}'
        }), 400

# Search in table
@app.route('/api/database/table/search', methods=['POST'])
def search_table():
    data = request.json
    connection_data = get_connection_from_request(data)
    table_name = data.get('tableName')
    search_query = data.get('query', '')
    
    if not connection_data or not table_name:
        return jsonify({
            'success': False,
            'message': 'Invalid request parameters'
        }), 400
    
    try:
        connection = create_connection(connection_data)
        cursor = connection.cursor(dictionary=True)
        
        # Get table columns
        cursor.execute(f"DESCRIBE `{table_name}`")
        columns = [column['Field'] for column in cursor.fetchall()]
        
        # Build WHERE clause with LIKE for each column
        if search_query:
            where_clauses = []
            for column in columns:
                where_clauses.append(f"`{column}` LIKE %s")
            
            where_clause = " OR ".join(where_clauses)
            query = f"SELECT * FROM `{table_name}` WHERE {where_clause} LIMIT 100"
            
            # Parameters for each column
            params = [f"%{search_query}%"] * len(columns)
            
            cursor.execute(query, params)
        else:
            cursor.execute(f"SELECT * FROM `{table_name}` LIMIT 100")
        
        rows = cursor.fetchall()
        
        # Convert any non-serializable objects to strings
        for row in rows:
            for key, value in row.items():
                if not isinstance(value, (str, int, float, bool, type(None))):
                    row[key] = str(value)
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': rows
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Search failed: {str(e)}'
        }), 400

# Add a new record to a table
@app.route('/api/database/table/add', methods=['POST'])
def add_record():
    data = request.json
    connection_data = get_connection_from_request(data)
    table_name = data.get('tableName')
    record = data.get('record', {})
    
    if not connection_data or not table_name or not record:
        return jsonify({
            'success': False,
            'message': 'Invalid request parameters'
        }), 400
    
    try:
        connection = create_connection(connection_data)
        cursor = connection.cursor()
        
        # Build INSERT query
        columns = list(record.keys())
        values = list(record.values())
        placeholders = ', '.join(['%s'] * len(columns))
        
        query = f"INSERT INTO `{table_name}` (`{'`, `'.join(columns)}`) VALUES ({placeholders})"
        
        cursor.execute(query, values)
        connection.commit()
        
        result = {
            'success': True,
            'message': 'Record added successfully',
            'insertId': cursor.lastrowid
        }
        
        cursor.close()
        connection.close()
        
        return jsonify(result)
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Failed to add record: {str(e)}'
        }), 400

# Update a record in a table
@app.route('/api/database/table/update', methods=['POST'])
def update_record():
    data = request.json
    connection_data = get_connection_from_request(data)
    table_name = data.get('tableName')
    record = data.get('record', {})
    id_field = data.get('idField', 'id')
    id_value = data.get('idValue')
    
    if not connection_data or not table_name or not record or id_value is None:
        return jsonify({
            'success': False,
            'message': 'Invalid request parameters'
        }), 400
    
    try:
        connection = create_connection(connection_data)
        cursor = connection.cursor()
        
        # Build UPDATE query
        set_clause = ', '.join([f"`{column}` = %s" for column in record.keys()])
        query = f"UPDATE `{table_name}` SET {set_clause} WHERE `{id_field}` = %s"
        
        values = list(record.values())
        values.append(id_value)
        
        cursor.execute(query, values)
        connection.commit()
        
        result = {
            'success': True,
            'message': 'Record updated successfully',
            'affectedRows': cursor.rowcount
        }
        
        cursor.close()
        connection.close()
        
        return jsonify(result)
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Failed to update record: {str(e)}'
        }), 400

# Delete a record from a table
@app.route('/api/database/table/delete', methods=['POST'])
def delete_record():
    data = request.json
    connection_data = get_connection_from_request(data)
    table_name = data.get('tableName')
    id_field = data.get('idField', 'id')
    id_value = data.get('idValue')
    
    if not connection_data or not table_name or id_value is None:
        return jsonify({
            'success': False,
            'message': 'Invalid request parameters'
        }), 400
    
    try:
        connection = create_connection(connection_data)
        cursor = connection.cursor()
        
        query = f"DELETE FROM `{table_name}` WHERE `{id_field}` = %s"
        cursor.execute(query, (id_value,))
        connection.commit()
        
        result = {
            'success': True,
            'message': 'Record deleted successfully',
            'affectedRows': cursor.rowcount
        }
        
        cursor.close()
        connection.close()
        
        return jsonify(result)
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Failed to delete record: {str(e)}'
        }), 400

# User registration endpoint
@app.route('/api/register', methods=['POST'])
def register():
    global next_user_id
    data = request.json
    fullname = data.get('fullname')
    email = data.get('email')
    username = data.get('username')
    password = data.get('password')
    
    if not fullname or not email or not username or not password:
        return jsonify({
            'success': False,
            'message': 'All fields are required'
        }), 400
    
    if username in users:
        return jsonify({
            'success': False,
            'message': 'Username already exists'
        }), 400
    
    user_id = next_user_id
    next_user_id += 1
    
    users[username] = {
        'id': user_id,
        'fullname': fullname,
        'email': email,
        'username': username,
        'password_hash': generate_password_hash(password)
    }
    
    return jsonify({
        'success': True,
        'message': 'Registration successful'
    })

# User login endpoint
@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({
            'success': False,
            'message': 'Username and password are required'
        }), 400
    
    user = users.get(username)
    
    if not user or not check_password_hash(user['password_hash'], password):
        return jsonify({
            'success': False,
            'message': 'Invalid username or password'
        }), 401
    
    return jsonify({
        'success': True,
        'user': {
            'id': user['id'],
            'username': user['username'],
            'fullname': user['fullname'],
            'email': user['email']
        }
    })

# Profile update endpoint
@app.route('/api/profile/update', methods=['POST'])
def update_profile():
    data = request.json
    user_id = data.get('userId')
    fullname = data.get('fullname')
    email = data.get('email')
    password = data.get('password')
    
    # Find user by id
    user = None
    username = None
    for uname, u in users.items():
        if u['id'] == user_id:
            user = u
            username = uname
            break
    
    if not user:
        return jsonify({
            'success': False,
            'message': 'User not found'
        }), 404
    
    if fullname:
        user['fullname'] = fullname
    
    if email:
        user['email'] = email
    
    if password:
        user['password_hash'] = generate_password_hash(password)
    
    return jsonify({
        'success': True,
        'message': 'Profile updated successfully'
    })

# Helper functions
def get_connection_from_request(data):
    # Extract connection info from request
    if 'connectionId' in data:
        # In a real app, you would retrieve the stored connection info by ID
        # For simplicity, we expect the frontend to send all connection details
        return {
            'host': data.get('host', 'localhost'),
            'port': data.get('port', 3306),
            'user': data.get('user'),
            'password': data.get('password'),
            'database': data.get('database')
        }
    else:
        return {
            'host': data.get('host'),
            'port': data.get('port'),
            'user': data.get('user'),
            'password': data.get('password'),
            'database': data.get('database')
        }

def create_connection(connection_data):
    return mysql.connector.connect(
        host=connection_data['host'],
        port=connection_data['port'],
        user=connection_data['user'],
        password=connection_data['password'],
        database=connection_data['database']
    )

if __name__ == '__main__':
    app.run(debug=True, port=5000)
