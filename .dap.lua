return {
    {
        name = 'Debug PDE Manager',
        type = 'codelldb',
        sourceLanguages = { 'rust' },
        request = 'launch',
        cwd = '${workspaceFolder}',
        program = 'pde-manager',
        args = { '-i', '/home/ember/.pde' },
        stopOnEntry = false,
    },
}
