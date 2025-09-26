Stuff that I need to learn to do in neovim

    - Download
        - curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
        - sudo rm -rf /opt/nvim-linux-x86_64
        - sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz

    - Add to Path
    	- echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >> ~/.bashrc
    	- source ~/.bashrc
    	- 

	- How to open directories
		- nvim ~/Directory

	- How to open and close tree sidebar
		- Ctrl + N

    - How to name + save + close file
        - :wq (filename) 
            - preferring to go with camelCase due to this

    - Set up Neovim config folder
        - make folder
            - mkdir -p ~/.config/nvim/lua
        - edit config init lua
            - nano ~/.config/nvim/init.lua

	- Full ide set up 	
		- syntax highlighting
		- autofinish
			-indentation
                - done through shift < or > 
		-
