import { ChevronDown, ChevronRight, FileText, Folder, FolderPlus, Home, Plus, Search, Settings, Star, BookTemplate as Template, X } from 'lucide-react';
import { useEffect, useState, useRef, useCallback, DragEvent } from 'react';
import { clsx } from 'clsx';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useAuth } from '../lib/auth';
import { PostgrestError } from '@supabase/supabase-js';

interface WorkspaceFormData {
  name: string;
  description: string;
}

interface TreeItem {
  id: string;
  title: string;
  type: 'folder' | 'document';
  children?: TreeItem[];
}

const mockTree: TreeItem[] = [
  {
    id: '1',
    title: 'Getting Started',
    type: 'document'
  },
  {
    id: '2',
    title: 'Engineering',
    type: 'folder',
    children: [
      {
        id: '3',
        title: 'Architecture',
        type: 'document'
      },
      {
        id: '4',
        title: 'Backend',
        type: 'folder',
        children: [
          {
            id: '5',
            title: 'API Documentation',
            type: 'document'
          }
        ]
      }
    ]
  }
];

interface TreeNodeProps {
  item: TreeItem;
  level: number;
  onDelete: (id: string) => Promise<void>;
  onRename: (id: string, newTitle: string) => Promise<void>;
  onRefresh: () => Promise<void>;
}

function TreeNode({ item, level, onDelete, onRename, onRefresh }: TreeNodeProps) {
  const [isExpanded, setIsExpanded] = useState(true);
  const [showContextMenu, setShowContextMenu] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [isDragOver, setIsDragOver] = useState(false);
  const [contextMenuPosition, setContextMenuPosition] = useState({ x: 0, y: 0 });
  const [isRenaming, setIsRenaming] = useState(false);
  const [newTitle, setNewTitle] = useState(item.title);
  const contextMenuRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (contextMenuRef.current && !contextMenuRef.current.contains(event.target as Node)) {
        setShowContextMenu(false);
      }
    };

    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  }, []);

  const handleContextMenu = (e: React.MouseEvent) => {
    e.preventDefault();
    setContextMenuPosition({ x: e.clientX, y: e.clientY });
    setShowContextMenu(true);
  };

  const handleRename = async () => {
    if (newTitle.trim() && newTitle !== item.title) {
      await onRename(item.id, newTitle);
    }
    setIsRenaming(false);
  };

  const startRenaming = () => {
    setShowContextMenu(false);
    setIsRenaming(true);
    setNewTitle(item.title);
    // Focus the input after it's rendered
    setTimeout(() => inputRef.current?.focus(), 0);
  };

  const handleDelete = async () => {
    setShowContextMenu(false);
    if (confirm('Are you sure you want to delete this document?')) {
      await onDelete(item.id);
    }
  };
  
  const handleDragStart = (e: DragEvent<HTMLDivElement>) => {
    e.stopPropagation();
    setIsDragging(true);
    e.dataTransfer.setData('text/plain', item.id);
  };

  const handleDragEnd = () => {
    setIsDragging(false);
  };

  const handleDragOver = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    if (item.type === 'folder') {
      setIsDragOver(true);
    }
  };

  const handleDragLeave = (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragOver(false);
  };

  const handleDrop = async (e: DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragOver(false);

    if (item.type !== 'folder') return;

    const draggedId = e.dataTransfer.getData('text/plain');
    if (draggedId === item.id) return; // Prevent dropping on itself

    try {
      const { error } = await supabase
        .from('documents')
        .update({ parent_id: item.id })
        .eq('id', draggedId);

      if (error) throw error;
      // Refresh the document tree
      await onRefresh();
    } catch (error) {
      console.error('Error moving document:', error);
      alert('Failed to move document. Please try again.');
    }
  };
  
  return (
    <div
      draggable
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      className={clsx(
        'relative',
        isDragOver && 'bg-indigo-50 rounded'
      )}
    >
      <button
        onContextMenu={handleContextMenu}
        className={clsx(
          'w-full flex items-center py-1 px-2 text-sm rounded hover:bg-gray-100 transition-colors',
          { 'text-gray-900': item.type === 'folder', 'text-gray-700': item.type === 'document' },
          isDragging && 'opacity-50'
        )}
        style={{ paddingLeft: `${level * 12 + 8}px` }}
      >
        {item.type === 'folder' ? (
          <span className="flex items-center">
            {isExpanded ? (
              <ChevronDown className="w-4 h-4" onClick={() => setIsExpanded(false)} />
            ) : (
              <ChevronRight className="w-4 h-4" onClick={() => setIsExpanded(true)} />
            )}
            <Folder className="w-4 h-4 ml-1 mr-2 text-gray-500" />
          </span>
        ) : (
          <FileText className="w-4 h-4 mr-2" />
        )}
        {isRenaming ? (
          <input
            ref={inputRef}
            type="text"
            value={newTitle}
            onChange={(e) => setNewTitle(e.target.value)}
            onBlur={handleRename}
            onKeyDown={(e) => {
              if (e.key === 'Enter') handleRename();
              if (e.key === 'Escape') setIsRenaming(false);
            }}
            className="flex-1 bg-transparent border-none focus:outline-none focus:ring-1 focus:ring-indigo-500 rounded px-1"
            onClick={(e) => e.stopPropagation()}
          />
        ) : (
          item.title
        )}
      </button>
      
      {showContextMenu && (
        <div
          ref={contextMenuRef}
          style={{
            position: 'fixed',
            left: contextMenuPosition.x,
            top: contextMenuPosition.y,
          }}
          className="bg-white rounded-lg shadow-lg py-1 w-48 z-50 border border-gray-200"
        >
          <button
            onClick={startRenaming}
            className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
          >
            Rename
          </button>
          <button
            onClick={handleDelete}
            className="w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-gray-100"
          >
            Delete
          </button>
        </div>
      )}
      
      {item.children && isExpanded && (
        <div>
          {item.children.map((child) => (
            <TreeNode 
              key={child.id}
              item={child}
              level={level + 1}
              onDelete={onDelete}
              onRename={onRename}
              onRename={onRename}
              onRefresh={onRefresh} />
          ))}
        </div>
      )}
    </div>
  );
}

export default function Sidebar() {
  const [activeTab, setActiveTab] = useState<'pages' | 'templates'>('pages');
  const [documents, setDocuments] = useState<TreeItem[]>([]);
  const [showCreateWorkspace, setShowCreateWorkspace] = useState(false);
  const [userHasWorkspace, setUserHasWorkspace] = useState(false);
  const [showCreateMenu, setShowCreateMenu] = useState(false);
  const [workspaceLoading, setWorkspaceLoading] = useState(true);
  const [retryCount, setRetryCount] = useState(0);
  const createMenuRef = useRef<HTMLDivElement>(null);
  const [workspaceForm, setWorkspaceForm] = useState<WorkspaceFormData>({
    name: '',
    description: ''
  });
  const [isCreatingWorkspace, setIsCreatingWorkspace] = useState(false);
  const { user } = useAuth();
  const navigate = useNavigate();

  const createWorkspace = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!user) return;
    
    try {
      setIsCreatingWorkspace(true);

      const { data: workspace, error: workspaceError } = await supabase
        .from('workspaces')
        .insert({
          name: workspaceForm.name,
          description: workspaceForm.description,
          owner_id: user.id
        })
        .select()
        .single();

      if (workspaceError) throw workspaceError;

      const { error: memberError } = await supabase
        .from('workspace_members')
        .insert({
          workspace_id: workspace.id,
          user_id: user.id,
          role: 'admin'
        });

      if (memberError) throw memberError;

      setWorkspaceForm({ name: '', description: '' });
      setShowCreateWorkspace(false);
      setUserHasWorkspace(true);
      fetchDocuments();
    } catch (error) {
      console.error('Error creating workspace:', error);
      alert('Failed to create workspace. Please try again.');
    } finally {
      setIsCreatingWorkspace(false);
    }
  };

  const checkForWorkspace = async () => {
    if (!user) return;

    const maxRetries = 3;
    const retryDelay = 1000; // 1 second

    try {
      setWorkspaceLoading(true);

      const { data: workspace, error } = await supabase
        .from('workspaces')
        .select('id')
        .eq('owner_id', user.id)
        .limit(1)
        .single();

      if (error) {
        // Handle "no rows returned" separately
        if (error.code === 'PGRST116') {
          setUserHasWorkspace(false);
          setShowCreateWorkspace(true);
          setWorkspaceLoading(false);
          return;
        }

        // For network errors, retry if we haven't exceeded max retries
        if (retryCount < maxRetries) {
          setRetryCount(prev => prev + 1);
          setTimeout(() => checkForWorkspace(), retryDelay);
          return;
        }

        // If we've exhausted retries, set default state
        console.error('Error checking for workspace after retries:', error);
        setUserHasWorkspace(false);
        setShowCreateWorkspace(true);
      } else {
        setUserHasWorkspace(!!workspace);
        setShowCreateWorkspace(!workspace);
        setRetryCount(0); // Reset retry count on success
      }

    } catch (error) {
      const pgError = error as PostgrestError;
      console.error('Error checking for workspace:', pgError?.message || error);
      
      // Retry on network errors
      if (retryCount < maxRetries) {
        setRetryCount(prev => prev + 1);
        setTimeout(() => checkForWorkspace(), retryDelay);
        return;
      }

      // Default to showing create workspace if all retries fail
      setUserHasWorkspace(false);
      setShowCreateWorkspace(true);
    } finally {
      setWorkspaceLoading(false);
    }
  };

  const createDocument = async (parentId: string | null = null) => {
    try {
      if (!user) {
        navigate('/signin');
        throw new Error('Please sign in to create documents');
      }

      // If no workspace exists, ask to create one first
      if (!userHasWorkspace) {
        setShowCreateWorkspace(true);
        throw new Error('Please create a workspace first to add documents');
      }

      const { data: workspace } = await supabase
        .from('workspaces')
        .select('id')
        .eq('owner_id', user.id)
        .limit(1)
        .single();

      if (!workspace) {
        throw new Error('No workspace found');
      }

      const { data: document, error } = await supabase
        .from('documents')
        .insert({
          title: 'Untitled Document',
          workspace_id: workspace.id,
          parent_id: parentId,
          created_by: user.id,
          content: null
        })
        .select()
        .single();

      if (error) {
        console.error("Error creating document:", error);
        throw new Error("Failed to create document. Database error.");
      }

      // Refresh documents
      fetchDocuments();
      
      // Return the new document ID for navigation
      return document.id;
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to create document';
      console.error('Error creating document:', message);
      alert(message);
      return null;
    }
  };

  const createFolder = async (parentId: string | null = null) => {
    try {
      if (!user) {
        navigate('/signin');
        throw new Error('Please sign in to create folders');
      }

      if (!userHasWorkspace) {
        setShowCreateWorkspace(true);
        throw new Error('Please create a workspace first');
      }

      const { data: workspace } = await supabase
        .from('workspaces')
        .select('id')
        .eq('owner_id', user.id)
        .limit(1)
        .single();

      if (!workspace) {
        throw new Error('No workspace found');
      }

      const { data: folder, error } = await supabase
        .from('documents')
        .insert({
          title: 'New Folder',
          workspace_id: workspace.id,
          parent_id: parentId,
          created_by: user.id,
          content: null,
          is_folder: true
        })
        .select()
        .single();

      if (error) throw error;

      fetchDocuments();
      return folder.id;
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to create folder';
      console.error('Error creating folder:', message);
      alert(message);
      return null;
    }
  };

  // Close create menu when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (createMenuRef.current && !createMenuRef.current.contains(event.target as Node)) {
        setShowCreateMenu(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const deleteDocument = async (id: string) => {
    try {
      const { error } = await supabase
        .from('documents')
        .delete()
        .eq('id', id);

      if (error) throw error;

      // Refresh documents list
      fetchDocuments();
    } catch (error) {
      console.error('Error deleting document:', error);
      alert('Failed to delete document. Please try again.');
    }
  };

  const renameDocument = async (id: string, newTitle: string) => {
    try {
      const { error } = await supabase
        .from('documents')
        .update({ title: newTitle })
        .eq('id', id);

      if (error) throw error;

      // Refresh documents list
      fetchDocuments();
    } catch (error) {
      console.error('Error renaming document:', error);
      alert('Failed to rename document. Please try again.');
    }
  };

  const fetchDocuments = async () => {
    try {
      if (!user) {
        console.error('No authenticated user');
        return;
      }
      
      // Get all documents user has access to (based on RLS policies)
      const { data: documentsData, error } = await supabase
        .from('documents')
        .select('*')
        .order('created_at', { ascending: true });

      if (error) {
        console.error('Documents fetch error:', error);
        return;
      }

      if (!documentsData || documentsData.length === 0) {
        setDocuments([]);
        return;
      }

      // Convert flat structure to tree
      const documentsMap = new Map<string, TreeItem>();
      const tree: TreeItem[] = [];

      // First pass: Create all nodes
      documentsData.forEach(doc => {
        documentsMap.set(doc.id, {
          id: doc.id,
          title: doc.title,
          type: doc.is_folder ? 'folder' : 'document',
          children: []
        });
      });

      // Second pass: Build tree structure
      documentsData.forEach(doc => {
        const node = documentsMap.get(doc.id);
        if (node) {
          if (doc.parent_id) {
            const parent = documentsMap.get(doc.parent_id);
            if (parent) {
              if (!parent.children) parent.children = [];
              parent.children.push(node);
            } else {
              // If parent not found, add to root
              tree.push(node);
            }
          } else {
            tree.push(node);
          }
        }
      });

      setDocuments(tree);
    } catch (error) {
      console.error('Error fetching documents:', error);
      setDocuments([]);
    }
  };

  useEffect(() => {
    if (user) {
      checkForWorkspace();
      fetchDocuments();
    }
  }, [user]);

  // Fetch documents when workspace status changes
  useEffect(() => {
    if (userHasWorkspace) {
      fetchDocuments();
    }
  }, [userHasWorkspace]);

  // Loading state
  if (workspaceLoading) {
    return (
      <div className="w-64 bg-gray-50 border-r border-gray-200 h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  return (
    <div className="w-64 bg-gray-50 border-r border-gray-200 h-screen flex flex-col">
      <div className="p-4 border-b border-gray-200">
        <div className="flex items-center justify-between mb-4">
          <button
            className="flex items-center space-x-2 text-gray-700 hover:text-indigo-600 transition-colors"
          >
            <Home className="w-6 h-6" />
            <span className="font-medium">Workspace</span>
          </button>
          <button
            onClick={() => setShowCreateWorkspace(true)}
            className="p-1.5 text-gray-500 hover:text-gray-700 rounded-md hover:bg-gray-100 transition-colors"
            title="Create new workspace"
          >
            <Plus className="w-5 h-5" />
          </button>
        </div>
        <div className="relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" />
          <input
            type="text"
            placeholder="Search docs..."
            className="w-full pl-9 pr-4 py-2 bg-white rounded-md border border-gray-200 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
          />
        </div>
      </div>
      
      {!userHasWorkspace && !showCreateWorkspace && (
        <div className="flex-1 flex flex-col items-center justify-center p-6 text-center">
          <FolderPlus className="w-12 h-12 text-gray-400 mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">No Workspaces Yet</h3>
          <p className="text-gray-500 mb-4">Create a workspace to start adding documents</p>
          <button
            onClick={() => setShowCreateWorkspace(true)}
            className="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 transition-colors"
          >
            Create Workspace
          </button>
        </div>
      )}
      
      {userHasWorkspace && (
        <>
          <div className="flex border-b border-gray-200">
            <button
              className={clsx(
                'flex-1 px-4 py-2 text-sm font-medium border-b-2 transition-colors',
                activeTab === 'pages'
                  ? 'border-indigo-500 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              )}
              onClick={() => setActiveTab('pages')}
            >
              Pages
            </button>
            <button
              className={clsx(
                'flex-1 px-4 py-2 text-sm font-medium border-b-2 transition-colors',
                activeTab === 'templates'
                  ? 'border-indigo-500 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700'
              )}
              onClick={() => setActiveTab('templates')}
            >
              Templates
            </button>
          </div>
          
          <nav className="flex-1 overflow-y-auto">
            {activeTab === 'pages' ? (
              <div className="p-2">
                <div className="flex items-center justify-between px-2 py-1 mb-2">
                  <span className="text-xs font-medium text-gray-500 uppercase">Quick Access</span>
                </div>
                <button className="w-full flex items-center space-x-2 px-2 py-1 text-sm text-gray-700 rounded hover:bg-gray-100 transition-colors mb-4">
                  <Star className="w-4 h-4" />
                  <span>Starred Pages</span>
                </button>
                
                <div className="flex items-center justify-between px-2 py-1 mb-2">
                  <span className="text-xs font-medium text-gray-500 uppercase">Pages</span>
                  <div className="relative" ref={createMenuRef}>
                    <button 
                      onClick={() => setShowCreateMenu(!showCreateMenu)}
                      className="p-1 text-gray-500 hover:text-gray-700 rounded hover:bg-gray-100"
                    >
                      <Plus className="w-4 h-4" />
                    </button>
                    
                    {showCreateMenu && (
                      <div className="absolute right-0 mt-1 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 z-10">
                        <div className="py-1" role="menu">
                          <button
                            onClick={() => {
                              createDocument();
                              setShowCreateMenu(false);
                            }}
                            className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 flex items-center"
                            role="menuitem"
                          >
                            <FileText className="w-4 h-4 mr-2" />
                            New Document
                          </button>
                          <button
                            onClick={() => {
                              createFolder();
                              setShowCreateMenu(false);
                            }}
                            className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 flex items-center"
                            role="menuitem"
                          >
                            <FolderPlus className="w-4 h-4 mr-2" />
                            New Folder
                          </button>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
                
                {documents.length > 0 ? (
                  documents.map((item) => (
                    <TreeNode
                      key={item.id}
                      item={item}
                      level={0}
                      onDelete={deleteDocument}
                      onRename={renameDocument}
                      onRename={renameDocument}
                      onRefresh={fetchDocuments} />
                  ))
                ) : (
                  <div className="text-center py-8 text-gray-500">
                    <FileText className="w-10 h-10 mx-auto text-gray-300 mb-2" />
                    <p>No documents yet</p>
                    <button 
                      onClick={() => createDocument()}
                      className="mt-2 text-indigo-600 hover:text-indigo-800 text-sm"
                    >
                      Create your first document
                    </button>
                  </div>
                )}
              </div>
            ) : (
              <div className="p-4 space-y-2">
                <button className="w-full flex items-center space-x-2 px-3 py-2 text-gray-700 rounded-md hover:bg-gray-100 transition-colors">
                  <Template className="w-5 h-5" />
                  <span>Meeting Notes</span>
                </button>
                <button className="w-full flex items-center space-x-2 px-3 py-2 text-gray-700 rounded-md hover:bg-gray-100 transition-colors">
                  <Template className="w-5 h-5" />
                  <span>Project Plan</span>
                </button>
                <button className="w-full flex items-center space-x-2 px-3 py-2 text-gray-700 rounded-md hover:bg-gray-100 transition-colors">
                  <Template className="w-5 h-5" />
                  <span>Documentation</span>
                </button>
              </div>
            )}
          </nav>
        </>
      )}

      {showCreateWorkspace && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold text-gray-900">Create Workspace</h2>
              {userHasWorkspace && (
                <button
                  onClick={() => setShowCreateWorkspace(false)}
                  className="text-gray-400 hover:text-gray-500"
                >
                  <X className="w-5 h-5" />
                </button>
              )}
            </div>
            
            <form onSubmit={createWorkspace} className="space-y-4">
              <div>
                <label htmlFor="workspace-name" className="block text-sm font-medium text-gray-700">
                  Workspace Name
                </label>
                <input
                  type="text"
                  id="workspace-name"
                  value={workspaceForm.name}
                  onChange={(e) => setWorkspaceForm(prev => ({ ...prev, name: e.target.value }))}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  placeholder="My Awesome Team"
                  required
                />
              </div>
              
              <div>
                <label htmlFor="workspace-description" className="block text-sm font-medium text-gray-700">
                  Description
                </label>
                <textarea
                  id="workspace-description"
                  value={workspaceForm.description}
                  onChange={(e) => setWorkspaceForm(prev => ({ ...prev, description: e.target.value }))}
                  rows={3}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                  placeholder="What's this workspace for?"
                />
              </div>
              
              <div className="flex justify-end space-x-3 pt-4">
                {userHasWorkspace && (
                  <button
                    type="button"
                    onClick={() => setShowCreateWorkspace(false)}
                    className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                  >
                    Cancel
                  </button>
                )}
                <button
                  type="submit"
                  disabled={isCreatingWorkspace || !workspaceForm.name.trim()}
                  className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 border border-transparent rounded-md shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50"
                >
                  {isCreatingWorkspace ? 'Creating...' : 'Create Workspace'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      <div className="p-4 border-t border-gray-200">
        <div className="flex items-center space-x-2 px-3 py-2 mb-2 rounded-md bg-gray-100">
          <img
            src="https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=facearea&facepad=2&w=256&h=256&q=80"
            alt="User avatar"
            className="w-6 h-6 rounded-full"
          />
          <span className="text-sm font-medium text-gray-700">{user?.email || "User"}</span>
        </div>
        <button className="w-full flex items-center space-x-2 px-3 py-2 text-gray-700 rounded-md hover:bg-gray-100 transition-colors">
          <Settings className="w-5 h-5" />
          <span>Settings</span>
        </button>
      </div>
    </div>
  );
}