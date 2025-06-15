        // --- Configuration ---
        const API_BASE_URL = 'http://localhost:5000/api/database'; // Adjust if your backend runs elsewhere

        // --- Application State ---
        const state = {
            currentPage: 'connect', // 'connect' or 'dashboard'
            dbConnection: null, // { host, port, user, password, database }
            // SECURITY_NOTE: Storing password in client-side state is not recommended for production.
            // Backend should ideally issue a session token.

            tables: [],
            selectedTable: '',
            tableColumns: [], // For the selected table
            tableData: [],    // Data for the selected table
            primaryKeyColumn: '', // User-defined primary key for the selected table

            // For Add/Edit Modals
            showAddModal: false,
            showEditModal: false,
            recordToEdit: null, // Stores the original record being edited
            currentFormData: {}, // For modal form fields

            // For Custom SQL
            customSql: '',
            sqlResult: null, // { type: 'data'/'message', content: [] or '' }

            isLoading: false,
            message: { type: '', text: '' }, // { type: 'success'/'error', text: '...' }
        };

        // --- Main App Container ---
        const appContainer = document.getElementById('app');

        // --- API Helper Functions ---
        async function apiCall(endpoint, method = 'POST', body = {}) {
            state.isLoading = true;
            state.message = { type: '', text: '' }; // Clear previous messages
            renderApp(); // Show loader

            // Include connection details in the body for all relevant requests
            const requestBody = {
                ...state.dbConnection, // host, port, user, password, database
                ...body
            };
            
            try {
                const response = await fetch(`${API_BASE_URL}${endpoint}`, {
                    method: method,
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(requestBody),
                });

                const responseData = await response.json();

                if (!response.ok || !responseData.success) {
                    throw new Error(responseData.message || `HTTP error! status: ${response.status}`);
                }
                return responseData;
            } catch (error) {
                console.error(`API call to ${endpoint} failed:`, error);
                state.message = { type: 'error', text: error.message || 'An unknown error occurred.' };
                throw error; // Re-throw to be caught by calling function
            } finally {
                state.isLoading = false;
                renderApp(); // Hide loader, show messages
            }
        }

        // --- Database Interaction Functions ---
        async function handleConnectSubmit(event) {
            event.preventDefault();
            const formData = new FormData(event.target);
            const connectionDetails = Object.fromEntries(formData.entries());
            // Convert port to number if it's not empty
            if (connectionDetails.port) {
                connectionDetails.port = parseInt(connectionDetails.port, 10);
            } else {
                delete connectionDetails.port; // Use default if empty
            }


            try {
                await apiCall('/connect', 'POST', connectionDetails);
                state.dbConnection = connectionDetails;
                state.currentPage = 'dashboard';
                state.message = { type: 'success', text: 'Successfully connected to the database!' };
                await loadTables(); // Load tables after successful connection
            } catch (error) {
                // Error message is already set by apiCall
                state.dbConnection = null; // Clear connection details on failure
            }
            renderApp();
        }

        function handleDisconnect() {
            state.dbConnection = null;
            state.currentPage = 'connect';
            state.tables = [];
            state.selectedTable = '';
            state.tableColumns = [];
            state.tableData = [];
            state.primaryKeyColumn = '';
            state.message = { type: 'info', text: 'Disconnected from database.' };
            renderApp();
        }

        async function loadTables() {
            if (!state.dbConnection) return;
            try {
                const data = await apiCall('/tables');
                state.tables = data.tables || [];
                if (state.tables.length > 0 && !state.selectedTable) {
                    // Optionally auto-select the first table
                    // state.selectedTable = state.tables[0];
                    // await loadTableData(state.selectedTable);
                } else if (state.tables.length === 0) {
                    state.selectedTable = '';
                    state.tableData = [];
                    state.tableColumns = [];
                }
                state.message = { type: 'success', text: 'Tables loaded successfully.'};
            } catch (error) {
                state.tables = [];
                // Error message handled by apiCall
            }
            renderApp();
        }

        async function loadTableData(tableName) {
            if (!state.dbConnection || !tableName) return;
            state.selectedTable = tableName;
            state.primaryKeyColumn = ''; // Reset PK column on table change
            try {
                const data = await apiCall('/table/data', 'POST', { tableName });
                state.tableData = data.data || [];
                if (state.tableData.length > 0) {
                    state.tableColumns = Object.keys(state.tableData[0]);
                    // Auto-detect potential ID column (simple heuristic)
                    const potentialId = state.tableColumns.find(col => col.toLowerCase() === 'id' || col.toLowerCase().endsWith('_id'));
                    if (potentialId) state.primaryKeyColumn = potentialId;

                } else {
                    state.tableColumns = []; // No data, no columns to infer
                    // Try to get columns if table is empty
                    try {
                        const describeData = await apiCall('/execute', 'POST', { query: `DESCRIBE \`${tableName}\`;` });
                        if (describeData.results && describeData.results.length > 0) {
                            state.tableColumns = describeData.results.map(col => col.Field);
                        }
                    } catch (descError) {
                        console.warn("Could not fetch columns for empty table:", descError);
                    }
                }
                 state.message = { type: 'success', text: `Data for table '${tableName}' loaded.` };
            } catch (error) {
                state.tableData = [];
                state.tableColumns = [];
            }
            renderApp();
        }
        
        function handleShowAddModal() {
            state.currentFormData = {}; // Clear form data
            state.tableColumns.forEach(col => state.currentFormData[col] = ''); // Initialize with empty strings
            state.showAddModal = true;
            renderApp();
        }

        function handleShowEditModal(record) {
            state.recordToEdit = record; // Store the original record
            state.currentFormData = { ...record }; // Copy record data to form
            state.showEditModal = true;
            renderApp();
        }

        function handleModalClose() {
            state.showAddModal = false;
            state.showEditModal = false;
            state.recordToEdit = null;
            state.currentFormData = {};
            renderApp();
        }

        function handleModalInputChange(event) {
            const { name, value } = event.target;
            state.currentFormData[name] = value;
        }

        async function handleSaveRecord(event) {
            event.preventDefault();
            if (!state.selectedTable) return;

            const recordData = { ...state.currentFormData };
            // Convert empty strings to null for backend, or handle as per DB requirements
            for (const key in recordData) {
                if (recordData[key] === '') {
                    // Decide: send as empty string, or null, or remove.
                    // For now, sending as is. Backend might need to handle type conversions.
                }
            }

            try {
                if (state.showAddModal) { // Adding new record
                    await apiCall('/table/add', 'POST', {
                        tableName: state.selectedTable,
                        record: recordData,
                    });
                    state.message = { type: 'success', text: 'Record added successfully!' };
                } else if (state.showEditModal && state.recordToEdit) { // Editing existing record
                    if (!state.primaryKeyColumn || !state.recordToEdit[state.primaryKeyColumn]) {
                        state.message = { type: 'error', text: 'Primary key column or value is missing for update.' };
                        renderApp();
                        return;
                    }
                    await apiCall('/table/update', 'POST', {
                        tableName: state.selectedTable,
                        idField: state.primaryKeyColumn,
                        idValue: state.recordToEdit[state.primaryKeyColumn],
                        record: recordData,
                    });
                    state.message = { type: 'success', text: 'Record updated successfully!' };
                }
                handleModalClose();
                await loadTableData(state.selectedTable); // Refresh data
            } catch (error) {
                // Error message handled by apiCall
            }
        }

        async function handleDeleteRecord(record) {
            if (!state.selectedTable || !state.primaryKeyColumn || !record[state.primaryKeyColumn]) {
                state.message = { type: 'error', text: 'Primary key column or value is missing for delete.' };
                renderApp();
                return;
            }
            if (!confirm(`Are you sure you want to delete this record? (ID: ${record[state.primaryKeyColumn]})`)) {
                return;
            }
            try {
                await apiCall('/table/delete', 'POST', {
                    tableName: state.selectedTable,
                    idField: state.primaryKeyColumn,
                    idValue: record[state.primaryKeyColumn],
                });
                state.message = { type: 'success', text: 'Record deleted successfully!' };
                await loadTableData(state.selectedTable); // Refresh data
            } catch (error) {
                // Error message handled by apiCall
            }
        }
        
        async function handleExecuteSql() {
            if (!state.customSql.trim()) {
                state.message = { type: 'error', text: 'SQL query cannot be empty.' };
                renderApp();
                return;
            }
            try {
                const response = await apiCall('/execute', 'POST', { query: state.customSql });
                if (response.results && Array.isArray(response.results)) {
                    state.sqlResult = { type: 'data', content: response.results };
                    state.message = { type: 'success', text: `Query executed. ${response.rowCount !== undefined ? response.rowCount + ' rows returned.' : (response.affectedRows !== undefined ? response.affectedRows + ' rows affected.' : '')}` };
                } else {
                     state.sqlResult = { type: 'message', content: response.message || 'Query executed with no data output.' };
                     state.message = { type: 'success', text: `Query executed. ${response.affectedRows !== undefined ? response.affectedRows + ' rows affected.' : 'Operation successful.'}` };
                }
            } catch (error) {
                state.sqlResult = { type: 'message', content: `Error: ${error.message}` };
            }
            renderApp();
        }


        // --- Rendering Functions ---
        function renderMessage() {
            if (!state.message.text) return '';
            const bgColor = state.message.type === 'success' ? 'bg-green-500' : (state.message.type === 'error' ? 'bg-red-500' : 'bg-blue-500');
            return `
                <div class="${bgColor} text-white p-3 rounded-md shadow-md mb-4 text-sm">
                    ${state.message.text}
                    <button onclick="clearMessage()" class="float-right font-bold">&times;</button>
                </div>
            `;
        }
        function clearMessage() {
            state.message = { type: '', text: '' };
            renderApp();
        }

        function renderLoader() {
            return state.isLoading ? '<div class="fixed inset-0 bg-gray-500 bg-opacity-50 flex items-center justify-center z-[100]"><div class="loader"></div></div>' : '';
        }

        function renderConnectPage() {
            return `
                <div class="flex-grow flex items-center justify-center p-4">
                    <div class="bg-white p-8 rounded-lg shadow-xl w-full max-w-md">
                        <h1 class="text-3xl font-bold text-center text-blue-600 mb-8">Connect to Database</h1>
                        <form id="connect-form" onsubmit="handleConnectSubmit(event)">
                            <div class="mb-4">
                                <label for="host" class="block text-sm font-medium text-gray-700 mb-1">Host</label>
                                <input type="text" name="host" id="host" value="localhost" class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500" required>
                            </div>
                            <div class="mb-4">
                                <label for="port" class="block text-sm font-medium text-gray-700 mb-1">Port</label>
                                <input type="number" name="port" id="port" value="3306" class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500" placeholder="Default: 3306">
                            </div>
                            <div class="mb-4">
                                <label for="user" class="block text-sm font-medium text-gray-700 mb-1">User</label>
                                <input type="text" name="user" id="user" value="root" class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500" required>
                            </div>
                            <div class="mb-4">
                                <label for="password" class="block text-sm font-medium text-gray-700 mb-1">Password</label>
                                <input type="password" name="password" id="password" class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500">
                            </div>
                            <div class="mb-6">
                                <label for="database" class="block text-sm font-medium text-gray-700 mb-1">Database</label>
                                <input type="text" name="database" id="database" class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500" required>
                            </div>
                            <button type="submit" class="w-full bg-blue-600 hover:bg-blue-700 text-white font-semibold py-2 px-4 rounded-md shadow-md transition duration-150 ease-in-out">
                                Connect
                            </button>
                        </form>
                    </div>
                </div>
            `;
        }

        function renderDashboardPage() {
            let tableDataHtml = '<p class="text-gray-500 mt-2">No table selected or table is empty.</p>';
            if (state.selectedTable && state.tableData.length > 0) {
                const headers = state.tableColumns.map(col => `<th class="p-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">${col}</th>`).join('');
                const rows = state.tableData.map(row => {
                    const cells = state.tableColumns.map(col => `<td class="p-3 text-sm text-gray-700 whitespace-nowrap">${row[col] === null || row[col] === undefined ? 'NULL' : row[col]}</td>`).join('');
                    const pkValue = state.primaryKeyColumn ? row[state.primaryKeyColumn] : null;
                    const actionsEnabled = state.primaryKeyColumn && pkValue !== null && pkValue !== undefined;
                    const editButton = `<button ${actionsEnabled ? '' : 'disabled'} onclick='handleShowEditModal(${JSON.stringify(row)})' class="text-blue-500 hover:text-blue-700 disabled:text-gray-400 disabled:cursor-not-allowed mr-2"><i class="fas fa-edit"></i></button>`;
                    const deleteButton = `<button ${actionsEnabled ? '' : 'disabled'} onclick='handleDeleteRecord(${JSON.stringify(row)})' class="text-red-500 hover:text-red-700 disabled:text-gray-400 disabled:cursor-not-allowed"><i class="fas fa-trash"></i></button>`;
                    return `<tr class="hover:bg-gray-50 border-b border-gray-200">${cells}<td class="p-3 text-sm text-gray-700 whitespace-nowrap">${editButton}${deleteButton}</td></tr>`;
                }).join('');
                tableDataHtml = `
                    <div class="overflow-x-auto shadow-md rounded-lg mt-4">
                        <table class="min-w-full bg-white">
                            <thead class="bg-gray-50"><tr>${headers}<th class="p-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th></tr></thead>
                            <tbody class="divide-y divide-gray-200">${rows}</tbody>
                        </table>
                    </div>
                `;
            } else if (state.selectedTable && state.tableColumns.length > 0 && state.tableData.length === 0) {
                 tableDataHtml = '<p class="text-gray-600 mt-4 p-4 bg-yellow-100 border border-yellow-300 rounded-md">Table is empty. You can add records.</p>';
            }


            let sqlResultHtml = '';
            if (state.sqlResult) {
                if (state.sqlResult.type === 'data' && state.sqlResult.content.length > 0) {
                    const headers = Object.keys(state.sqlResult.content[0]).map(col => `<th class="p-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">${col}</th>`).join('');
                    const rows = state.sqlResult.content.map(row => {
                        const cells = Object.values(row).map(val => `<td class="p-2 text-sm text-gray-700 whitespace-nowrap">${val === null || val === undefined ? 'NULL' : val}</td>`).join('');
                        return `<tr class="hover:bg-gray-50 border-b border-gray-200">${cells}</tr>`;
                    }).join('');
                    sqlResultHtml = `
                        <h3 class="text-lg font-semibold mt-4 mb-2">Query Result:</h3>
                        <div class="overflow-x-auto shadow-md rounded-lg">
                            <table class="min-w-full bg-white">
                                <thead class="bg-gray-50"><tr>${headers}</tr></thead>
                                <tbody class="divide-y divide-gray-200">${rows}</tbody>
                            </table>
                        </div>`;
                } else {
                    sqlResultHtml = `<div class="mt-4 p-3 bg-blue-100 border border-blue-300 rounded-md text-blue-700">${state.sqlResult.content || 'No results or non-SELECT query executed.'}</div>`;
                }
            }

            return `
                <header class="bg-white shadow-md p-4">
                    <div class="container mx-auto flex justify-between items-center">
                        <h1 class="text-2xl font-bold text-blue-600">Database Dashboard</h1>
                        <div>
                            <span class="text-sm text-gray-600 mr-2">Connected to: ${state.dbConnection.host}/${state.dbConnection.database} as ${state.dbConnection.user}</span>
                            <button onclick="handleDisconnect()" class="bg-red-500 hover:bg-red-600 text-white text-sm font-medium py-2 px-3 rounded-md shadow-sm transition duration-150">Disconnect</button>
                        </div>
                    </div>
                </header>
                <main class="flex-grow container mx-auto p-4 md:p-6">
                    <section class="bg-white p-6 rounded-lg shadow-lg mb-6">
                        <h2 class="text-xl font-semibold text-gray-700 mb-3">Tables</h2>
                        <div class="flex flex-wrap gap-4 items-center">
                            <select id="table-select" onchange="loadTableData(this.value)" class="p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 flex-grow md:flex-grow-0 md:min-w-[200px]">
                                <option value="">-- Select a Table --</option>
                                ${state.tables.map(table => `<option value="${table}" ${state.selectedTable === table ? 'selected' : ''}>${table}</option>`).join('')}
                            </select>
                            <button onclick="loadTables()" class="bg-blue-500 hover:bg-blue-600 text-white text-sm font-medium py-2 px-3 rounded-md shadow-sm transition duration-150">
                                <i class="fas fa-sync-alt mr-1"></i> Refresh Tables
                            </button>
                        </div>
                    </section>

                    ${state.selectedTable ? `
                    <section class="bg-white p-6 rounded-lg shadow-lg mb-6">
                        <div class="flex justify-between items-center mb-3">
                            <h2 class="text-xl font-semibold text-gray-700">Data for: <span class="text-blue-600">${state.selectedTable}</span></h2>
                            <button onclick="handleShowAddModal()" class="bg-green-500 hover:bg-green-600 text-white font-medium py-2 px-4 rounded-md shadow-sm transition duration-150">
                                <i class="fas fa-plus mr-1"></i> Add Record
                            </button>
                        </div>
                        <div class="mb-3">
                            <label for="primary-key-column" class="block text-sm font-medium text-gray-700">Primary Key Column for Edit/Delete:</label>
                            <input type="text" id="primary-key-column" value="${state.primaryKeyColumn}" 
                                   onchange="state.primaryKeyColumn = this.value; renderApp();" 
                                   placeholder="e.g., id, user_id (case sensitive)"
                                   class="mt-1 p-2 w-full md:w-1/2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500">
                            ${!state.primaryKeyColumn && state.tableData.length > 0 ? '<p class="text-xs text-orange-500 mt-1">Specify PK to enable Edit/Delete.</p>' : ''}
                        </div>
                        ${tableDataHtml}
                    </section>
                    ` : ''}
                    
                    <section class="bg-white p-6 rounded-lg shadow-lg">
                        <h2 class="text-xl font-semibold text-gray-700 mb-3">Custom SQL Query</h2>
                        <textarea id="custom-sql" class="w-full p-2 border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 h-32" 
                                  placeholder="Enter your SQL query here (e.g., SELECT * FROM your_table WHERE id = 1)"
                                  oninput="state.customSql = this.value">${state.customSql}</textarea>
                        <button onclick="handleExecuteSql()" class="mt-3 bg-purple-500 hover:bg-purple-600 text-white font-medium py-2 px-4 rounded-md shadow-sm transition duration-150">
                            <i class="fas fa-play mr-1"></i> Execute Query
                        </button>
                        ${sqlResultHtml}
                    </section>
                </main>
            `;
        }
        
        function renderModal() {
            if (!state.showAddModal && !state.showEditModal) return '';

            const title = state.showAddModal ? 'Add New Record' : `Edit Record (ID: ${state.primaryKeyColumn ? state.recordToEdit?.[state.primaryKeyColumn] : 'N/A'})`;
            const formFields = state.tableColumns.map(column => `
                <div class="mb-4">
                    <label for="modal-${column}" class="block text-sm font-medium text-gray-700">${column}</label>
                    <input type="${typeof state.currentFormData[column] === 'number' ? 'number' : 'text'}" 
                           name="${column}" id="modal-${column}" 
                           value="${state.currentFormData[column] || ''}" 
                           oninput="handleModalInputChange(event)"
                           class="mt-1 p-2 w-full border border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500">
                </div>
            `).join('');

            return `
                <div class="modal-backdrop" onclick="handleModalClose()"></div>
                <div class="modal fixed top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 bg-white p-6 rounded-lg shadow-xl w-11/12 md:w-1/2 max-h-[80vh] overflow-y-auto">
                    <div class="flex justify-between items-center mb-4">
                        <h2 class="text-xl font-semibold">${title}</h2>
                        <button onclick="handleModalClose()" class="text-gray-500 hover:text-gray-700 text-2xl">&times;</button>
                    </div>
                    <form onsubmit="handleSaveRecord(event)">
                        ${formFields}
                        <div class="mt-6 flex justify-end gap-3">
                            <button type="button" onclick="handleModalClose()" class="bg-gray-300 hover:bg-gray-400 text-gray-800 font-medium py-2 px-4 rounded-md shadow-sm">Cancel</button>
                            <button type="submit" class="bg-blue-600 hover:bg-blue-700 text-white font-medium py-2 px-4 rounded-md shadow-sm">Save Record</button>
                        </div>
                    </form>
                </div>
            `;
        }


        // --- Main Render Function ---
        function renderApp() {
            let content = '';
            if (state.currentPage === 'connect') {
                content = renderConnectPage();
            } else if (state.currentPage === 'dashboard') {
                content = renderDashboardPage();
            }

            appContainer.innerHTML = `
                ${renderLoader()}
                <div class="fixed top-0 left-0 right-0 p-4 z-[60] pointer-events-none"> <div class="max-w-xl mx-auto pointer-events-auto">${renderMessage()}</div>
                </div>
                ${content}
                ${renderModal()}
                <footer class="text-center p-4 text-sm text-gray-500 border-t border-gray-200 mt-auto">
                    MySQL Database Manager &copy; ${new Date().getFullYear()}
                </footer>
            `;
            
            // Re-attach event listeners or ensure they are handled if elements are recreated
            // For simple onchange/onclick in HTML, this is fine.
            // For more complex listeners added via JS, they might need re-adding if their parent is re-rendered.
        }

        // --- Initial Load ---
        document.addEventListener('DOMContentLoaded', renderApp);