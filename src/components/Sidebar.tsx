import { ChevronDown, ChevronRight, FileText, Folder, FolderPlus, Home, Plus, Search, Settings, Star, BookTemplate as Template, X } from 'lucide-react';
import { useEffect, useState, useRef, useCallback } from 'react';
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
  parent_id?: string | null;
  position: number;
  children?: TreeItem[];
}

interface TreeNodeProps {
  item: TreeItem;
  level: number;
  onDelete: (id: string) => Promise<void>;
  onRename: (id: string, newTitle: string) => Promise<void>;
  onMove: (id: string, parentId: string | null, position: number) => Promise<void>;
  onRefresh: () => Promise<void>;
  expandedFolders: Set<string>;
  setExpandedFolders: React.Dispatch<React.SetStateAction<Set<string>>>;
}

function TreeNode({ 
  item, 
  level, 
  onDelete, 
  onRename, 
  onMove,
  onRefresh, 
  expandedFolders,
  setExpandedFolders 
}: TreeNodeProps) {
  const [showContextMenu, setShowContextMenu] = useState(false);
  const [isDragging, setIsDragging] = useState(false);
  const [isDragOver, setIsDragOver] = useState(false);
  const [dropIndicator, setDropIndicator] = useState<'before' | 'inside' | 'after' | null>(null);
  const [contextMenuPosition, setContextMenuPosition] = useState({ x: 0, y: 0 });
  const [isRenaming, setIsRenaming] = useState(false);
  const [newTitle, setNewTitle] = useState(item.title);
  const contextMenuRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const nodeRef = useRef<HTMLDivElement>(null);
  
  const isExpanded = expandedFolders.has(item.id);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (contextMenuRef.current && !contextMenuRef.current.contains(event.target as Node)) {
        setShowContextMenu(false);
      }
    };

    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  }, []);

  const toggleExpand = (e: React.MouseEvent) => {
    e.stopPropagation();
    setExpandedFolders(prev => {
      const newState = new Set(prev);
      if (newState.has(item.id)) {
        newState.delete(item.id);
      } else {
        newState.add(item.id);
      }
      return newState;
    });
  };

  const handleContextMenu = (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
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
    if (confirm(`Are you sure you want to delete this ${item.type}?`)) {
      await onDelete(item.id);
    }
  };
  
  const handleDragStart = (e: React.DragEvent<HTMLDivElement>) => {
    e.stopPropagation();
    setIsDragging(true);
    
    // Store complete item data
    e.dataTransfer.setData('application/json', JSON.stringify({
      id: item.id,
      type: item.type,
      title: item.title,
      parent_id: item.parent_id,
      position: item.position
    }));
    
    e.dataTransfer.effectAllowed = 'move';
    
    // Create a ghost image to show during drag
    const ghostElement = document.createElement('div');
    ghostElement.classList.add('bg-white', 'shadow-md', 'rounded', 'p-2', 'text-sm');
    ghostElement.textContent = item.title;
    document.body.appendChild(ghostElement);
    ghostElement.style.position = 'absolute';
    ghostElement.style.top = '-1000px';
    
    e.dataTransfer.setDragImage(ghostElement, 0, 0);
    
    // Set timeout to remove the ghost element
    setTimeout(() => {
      document.body.removeChild(ghostElement);
    }, 0);
  };

  const handleDragEnd = () => {
    setIsDragging(false);
    setDropIndicator(null);
  };

  const determineDropPosition = (e: React.DragEvent<HTMLDivElement>): 'before' | 'inside' | 'after' => {
    const rect = e.currentTarget.getBoundingClientRect();
    const y = e.clientY;
    
    // Calculate relative position
    const relativeY = y - rect.top;
    const height = rect.height;
    
    // Top 25% = before, Bottom 25% = after, Middle 50% = inside (if folder)
    if (relativeY < height * 0.25) {
      return 'before';
    } else if (relativeY > height * 0.75) {
      return 'after';
    } else if (item.type === 'folder') {
      return 'inside';
    } else {
      // For documents, just determine if it's before or after based on the middle point
      return relativeY < height * 0.5 ? 'before' : 'after';
    }
  };

  const handleDragOver = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    
    try {
      // Check if there's valid drag data
      const dragData = e.dataTransfer.getData('application/json');
      if (!dragData) return;
      
      const draggedItem = JSON.parse(dragData);
      
      // Don't allow dropping onto itself
      if (draggedItem.id === item.id) {
        setDropIndicator(null);
        return;
      }
      
      // Don't allow documents to contain other items
      if (item.type === 'document' && draggedItem.type === 'folder') {
        setDropIndicator(null);
        return;
      }
      
      // Determine the drop position
      const position = determineDropPosition(e);
      setDropIndicator(position);
      
      // Set appropriate drop effect
      e.dataTransfer.dropEffect = 'move';
    } catch (error) {
      // If we can't read the data yet (first dragover event), just set default indicator
      const position = determineDropPosition(e);
      setDropIndicator(position);
      e.dataTransfer.dropEffect = 'move';
    }
  };

  const handleDragLeave = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    setDropIndicator(null);
  };

  const handleDrop = async (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    
    // Reset visual states
    setDropIndicator(null);
    setDropIndicator(null);
    
    try {
      // Get the dragged item data
      const draggedItemJson = e.dataTransfer.getData('application/json');
      if (!draggedItemJson) return;
      
      const draggedItem = JSON.parse(draggedItemJson);
      if (!draggedItem.id) return;
      
      // Don't allow dropping an item onto itself
      if (draggedItem.id === item.id) return;
      
      // Don't allow documents to contain other items
      if (item.type === 'document' && draggedItem.type === 'folder') return;
      
      // Determine drop position
      const dropPosition = determineDropPosition(e);
      
      // Variables to track the new parent and position
      let newParentId: string | null = null;
      let newPosition: number = 0;
      
      if (dropPosition === 'inside' && item.type === 'folder') {
        // Dropping inside a folder
        newParentId = item.id;
        
        // Calculate position for inside drop - place at the end of the folder's children
        // If the folder is empty or collapsed, use position 0
        if (!item.children || !isExpanded) {
          newPosition = 0;
        } else {
          // Otherwise, find the last item's position and add 1
          const lastItem = item.children[item.children.length - 1];
          newPosition = lastItem.position + 1;
        }
        
        // Expand the folder when an item is dropped into it
        if (!isExpanded) {
          setExpandedFolders(prev => new Set(prev).add(item.id));
        }
      } else {
        // Dropping before or after an item
        // The new parent is the same as the current item's parent
        newParentId = item.parent_id;
        
        // Calculate position based on current item's position
        newPosition = item.position;
        
        // If dropping after, increment the position
        if (dropPosition === 'after') {
          newPosition += 1;
        }
      }
      
      // Call the move handler
      await onMove(draggedItem.id, newParentId, newPosition);
      
    } catch (error) {
      console.error('Error during drag and drop operation:', error);
      alert('Failed to move item. Please try again.');
    }
  };
  
  return (
    <div
      ref={nodeRef}
      draggable
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      onDrop={handleDrop}
      data-item-id={item.id}
      data-item-type={item.type}
      className={clsx(
        'relative mb-0.5 transition-all duration-200',
        isDragging && 'opacity-50',
        dropIndicator === 'before' && 'before:block before:absolute before:w-full before:h-0.5 before:top-0 before:bg-indigo-500 before:rounded-full before:-translate-y-0.5 before:shadow-lg before:animate-pulse',
        dropIndicator === 'after' && 'after:block after:absolute after:w-full after:h-0.5 after:bottom-0 after:bg-indigo-500 after:rounded-full after:translate-y-0.5 after:shadow-lg after:animate-pulse',
        dropIndicator === 'inside' && item.type === 'folder' && 'ring-2 ring-indigo-500 ring-inset rounded-md bg-indigo-50/50 shadow-inner'
      )}
    >
      <div
        onClick={() => item.type === 'folder' && toggleExpand}
        onContextMenu={handleContextMenu}
        className={clsx(
          'flex items-center py-1.5 px-2 rounded-md transition-all',
          !isDragging && 'hover:bg-gray-100 hover:shadow-sm',
          'active:scale-[0.98] active:bg-gray-200',
          { 
            'font-medium': item.type === 'folder',
            'bg-gray-100': showContextMenu
          }
        )}
      >
        <div style={{ paddingLeft: `${level * 12}px` }} className="flex items-center min-w-0 flex-1">
          {item.type === 'folder' ? (
            <span className="flex items-center cursor-pointer" onClick={toggleExpand}>
              {isExpanded ? (
                <ChevronDown className="w-4 h-4 text-gray-500 transition-transform" />
              ) : (
                <ChevronRight className="w-4 h-4 text-gray-500 transition-transform" />
              )}
              <Folder className={clsx(
                "w-4 h-4 ml-1 mr-2 transition-colors",
                isExpanded ? "text-indigo-500" : "text-gray-500"
              )} />
            </span>
          ) : (
            <FileText className="w-4 h-4 mr-2 text-gray-500 transition-colors group-hover:text-indigo-500" />
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
              className="flex-1 min-w-0 bg-white border border-gray-300 rounded py-0.5 px-1.5 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent shadow-sm"
              onClick={(e) => e.stopPropagation()}
            />
          ) : (
            <span className="truncate">{item.title}</span>
          )}
        </div>
      </div>
      
      {showContextMenu && (
        <div
          ref={contextMenuRef}
          style={{
            position: 'fixed',
            left: contextMenuPosition.x,
            top: contextMenuPosition.y,
          }}
          className="bg-white rounded-lg shadow-xl py-1 w-48 z-50 border border-gray-200 animate-in fade-in slide-in-from-top-2 duration-200"
        >
          <button
            onClick={startRenaming}
            className="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors flex items-center gap-2"
          >
            <span className="text-gray-400">✎</span>
            Rename
          </button>
          <button
            onClick={handleDelete}
            className="w-full text-left px-4 py-2 text-sm text-red-600 hover:bg-red-50 transition-colors flex items-center gap-2"
          >
            <span className="text-red-400">🗑</span>
            Delete
          </button>
        </div>
      )}
      
      {item.type === 'folder' && isExpanded && item.children && item.children.length > 0 && (
        <div className="ml-6 my-0.5">
          {item.children.map((child) => (
            <TreeNode 
              key={child.id}
              item={child}
              level={level + 1}
              onDelete={onDelete}
              onRename={onRename}
              onMove={onMove}
              onRefresh={onRefresh}
              expandedFolders={expandedFolders}
              setExpandedFolders={setExpandedFolders}
            />
          ))}
        </div>
      )}
    </div>
  );
}

export default function Sidebar() {
  const [activeTab, setActiveTab] = useState<'pages' | 'templates'>('pages');
  const [documents, setDocuments] = useState<TreeItem[]>([]);
  const [expandedFolders, setExpandedFolders] = useState<Set<string>>(new Set());
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
      
      // Get the maximum position for the new document's parent level
      let maxPosition = 0;
      
      const { data: positionData } = await supabase
        .from('documents')
        .select('position')
        .eq('parent_id', parentId)
        .order('position', { ascending: false })
        .limit(1);
        
      if (positionData && positionData.length > 0) {
        maxPosition = positionData[0].position + 1;
      }

      const { data: document, error } = await supabase
        .from('documents')
        .insert({
          title: 'Untitled Document',
          workspace_id: workspace.id,
          parent_id: parentId,
          created_by: user.id,
          content: null,
          position: maxPosition,
          is_folder: false
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
      
      // Get the maximum position for folders at this level
      let maxPosition = 0;
      
      const { data: folderPositionData } = await supabase
        .from('documents')
        .select('position')
        .eq('parent_id', parentId)
        .eq('is_folder', true)
        .order('position', { ascending: false })
        .limit(1);
        
      if (folderPositionData && folderPositionData.length > 0) {
        maxPosition = folderPositionData[0].position + 1;
      }
      
      // If there are no folders yet but there are documents, place folder at position 0
      // and shift all documents down
      const hasDocuments = await checkHasDocuments(parentId);
      
      // Create the new folder
      const { data: folder, error } = await supabase
        .from('documents')
        .insert({
          title: 'New Folder',
          workspace_id: workspace.id,
          parent_id: parentId,
          created_by: user.id,
          content: null,
          is_folder: true,
          position: maxPosition
        })
        .select()
        .single();

      if (error) throw error;
      
      // If there are documents and this is the first folder,
      // we need to reorder the documents to ensure folders stay at the top
      if (hasDocuments && maxPosition === 0) {
        await reorderDocumentsAfterNewFolder(parentId);
      }
      
      // Add the new folder to expanded folders state
      setExpandedFolders(prev => new Set(prev).add(folder.id));

      fetchDocuments();
      return folder.id;
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Failed to create folder';
      console.error('Error creating folder:', message);
      alert(message);
      return null;
    }
  };
  
  // Helper function to check if there are documents at a specific level
  const checkHasDocuments = async (parentId: string | null) => {
    const { data, error } = await supabase
      .from('documents')
      .select('id')
      .eq('parent_id', parentId)
      .eq('is_folder', false)
      .limit(1);
      
    return !error && data && data.length > 0;
  };
  
  // Helper function to reorder documents after a new folder is created
  const reorderDocumentsAfterNewFolder = async (parentId: string | null) => {
    try {
      // Get all documents (non-folders) at this level
      const { data: docs, error } = await supabase
        .from('documents')
        .select('id, position')
        .eq('parent_id', parentId)
        .eq('is_folder', false)
        .order('position', { ascending: true });
        
      if (error) throw error;
      
      if (docs && docs.length > 0) {
        // Create batch update with new positions
        const updates = docs.map((doc, index) => ({
          id: doc.id,
          position: index + 1 // Start after the folders (position 0)
        }));
        
        // Update all document positions
        const { error: updateError } = await supabase
          .from('documents')
          .upsert(updates);
          
        if (updateError) throw updateError;
      }
    } catch (error) {
      console.error('Error reordering documents:', error);
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

  // Improved move function that handles reordering correctly
  const moveItem = async (id: string, parentId: string | null, position: number) => {
    try {
      // Update the document's parent and position
      const { error: updateError } = await supabase
        .from('documents')
        .update({
          parent_id: parentId,
          position: position
        })
        .eq('id', id);
        
      if (updateError) throw updateError;

      // Refresh documents to show the updated structure
      await fetchDocuments();
    } catch (error) {
      console.error('Error moving document:', error);
      alert('Failed to move document. Please try again.');
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
        .order('position', { ascending: true });

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
          parent_id: doc.parent_id,
          position: doc.position || 0,
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

      // Sort each level: folders first, then documents, both by position
      const sortByTypeAndPosition = (items: TreeItem[]) => {
        // First separate folders and documents
        const folders = items.filter(item => item.type === 'folder');
        const documents = items.filter(item => item.type === 'document');
        
        // Sort each group by position
        folders.sort((a, b) => a.position - b.position);
        documents.sort((a, b) => a.position - b.position);
        
        // Combine: folders first, then documents
        const sorted = [...folders, ...documents];
        
        // Recursively sort children
        sorted.forEach(item => {
          if (item.children && item.children.length > 0) {
            item.children = sortByTypeAndPosition(item.children);
          }
        });
        
        return sorted;
      };

      // Apply sorting to the tree
      const sortedTree = sortByTypeAndPosition(tree);
      setDocuments(sortedTree);
      
      // Initialize expanded folders state for new folders
      const shouldExpand = new Set<string>(expandedFolders);
      const processNode = (node: TreeItem) => {
        if (node.type === 'folder') {
          // Auto-expand folders with recent activity or newly created folders
          if (node.children && node.children.length > 0) {
            shouldExpand.add(node.id);
          }
          
          // Process children recursively
          node.children?.forEach(processNode);
        }
      };
      
      // Process the tree to find folders to expand
      sortedTree.forEach(processNode);
      
      // Update expanded folders state
      setExpandedFolders(shouldExpand);
    } catch (error) {
      console.error('Error fetching documents:', error);
      setDocuments([]);
    }
  };
  
  // Initial data loading
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
                
                {/* Document Tree */}
                <div className="mt-1 pb-4">
                  {documents.length > 0 ? (
                    <div className="space-y-0.5">
                      {documents.map((item) => (
                        <TreeNode
                          key={item.id}
                          item={item}
                          level={0}
                          onDelete={deleteDocument}
                          onRename={renameDocument}
                          onMove={moveItem}
                          onRefresh={fetchDocuments}
                          expandedFolders={expandedFolders}
                          setExpandedFolders={setExpandedFolders}
                        />
                      ))}
                    </div>
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