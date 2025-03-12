import React, { useState, useEffect } from 'react';
import { Routes, Route } from 'react-router-dom';
import SignIn from './pages/SignIn';
import Register from './pages/Register';
import ProtectedRoute from './components/ProtectedRoute';
import Editor from './components/Editor';
import Sidebar from './components/Sidebar';
import { Plus, Star } from 'lucide-react';
import { clsx } from 'clsx';
import { supabase } from './lib/supabase';

interface Document {
  id: string;
  title: string;
  content: any;
  created_by: string;
  updated_at: string;
}

function Dashboard() {
  const [currentDocument, setCurrentDocument] = useState<Document | null>(null);
  const [isStarred, setIsStarred] = useState(false);

  const saveDocument = async (updates: Partial<Document>) => {
    if (!currentDocument) return;

    try {
      const { error } = await supabase
        .from('documents')
        .update({
          ...updates,
          updated_at: new Date().toISOString()
        })
        .eq('id', currentDocument.id);

      if (error) throw error;
    } catch (error) {
      console.error('Error saving document:', error);
    }
  };

  const handleTitleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newTitle = e.target.value;
    setCurrentDocument(prev => prev ? { ...prev, title: newTitle } : null);
    saveDocument({ title: newTitle });
  };

  return (
    <div className="flex min-h-screen bg-gray-100">
      <Sidebar />
      <main className="flex-1 p-8">
        <div className="max-w-4xl mx-auto space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-4">
              <input
                type="text"
                placeholder="Untitled Document"
                value={currentDocument?.title || ''}
                onChange={handleTitleChange}
                className="text-3xl font-bold bg-transparent border-none focus:outline-none focus:ring-0 placeholder-gray-400"
              />
              <button 
                onClick={() => setIsStarred(!isStarred)}
                className={clsx(
                  "p-1 transition-colors",
                  isStarred ? "text-yellow-500" : "text-gray-400 hover:text-yellow-500"
                )}
              >
                <Star className="w-6 h-6" />
              </button>
            </div>
            <div className="flex items-center space-x-2">
              <button className="inline-flex items-center px-3 py-1.5 border border-gray-300 shadow-sm text-sm font-medium rounded text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                <Plus className="w-4 h-4 mr-1" />
                Add to page
              </button>
              <button className="inline-flex items-center px-3 py-1.5 border border-transparent text-sm font-medium rounded shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                Share
              </button>
            </div>
          </div>
          
          <div className="flex items-center space-x-4 text-sm text-gray-500">
            {currentDocument && (
              <>
                <span>Last edited {new Date(currentDocument.updated_at).toLocaleDateString()}</span>
                <span>•</span>
                <span>{new Date(currentDocument.updated_at).toLocaleTimeString()}</span>
              </>
            )}
          </div>
          
          <input
            type="text"
            placeholder="Untitled Document"
            className="w-full mb-4 text-3xl font-bold bg-transparent border-none focus:outline-none focus:ring-0 placeholder-gray-400"
          />
          <Editor 
            content={currentDocument?.content}
            onUpdate={(content) => saveDocument({ content })}
          />
        </div>
      </main>
    </div>
  );
}

function App() {
  return (
    <Routes>
      <Route path="/signin" element={<SignIn />} />
      <Route path="/register" element={<Register />} />
      <Route path="/" element={
        <ProtectedRoute>
          <Dashboard />
        </ProtectedRoute>
      } />
    </Routes>
  );
}

export default App;
