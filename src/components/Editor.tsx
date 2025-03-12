import { useEditor, EditorContent } from '@tiptap/react';
import { Editor as CoreEditor, type EditorOptions } from '@tiptap/core';
import StarterKit from '@tiptap/starter-kit';
import Placeholder from '@tiptap/extension-placeholder';
import Highlight from '@tiptap/extension-highlight';
import TaskList from '@tiptap/extension-task-list';
import TaskItem from '@tiptap/extension-task-item';
import Link from '@tiptap/extension-link';
import Image from '@tiptap/extension-image';
import { 
  Bold, 
  Italic, 
  List, 
  ListOrdered, 
  Heading1, 
  Heading2, 
  Quote,
  CheckSquare,
  Link as LinkIcon,
  Highlighter,
  Image as ImageIcon
} from 'lucide-react';
import { clsx } from 'clsx';

interface MenuBarProps {
  editor: CoreEditor | null;
}

const isValidImageUrl = (url: string) => {
  return url.match(/\.(jpeg|jpg|gif|png|webp)$/) != null;
};

const handleDirectImagePaste = (editor: CoreEditor | null, items: DataTransferItem[]) => {
  const imageItem = items.find(item => item.type.startsWith('image'));
  if (!imageItem || !editor) return false;
  
  const file = imageItem.getAsFile();
  if (file) {
    handlePasteImage(editor, file);
    return true;
  }
  return false;
};

const handleImageUrlPaste = (editor: CoreEditor | null, text: string) => {
  if (!isValidImageUrl(text) || !editor) return false;
  
  editor.chain().focus().setImage({ src: text }).run();
  return true;
};

const handleGoogleDocsPaste = (editor: CoreEditor | null, html: string) => {
  if (!editor) return false;
  
  if (!html.includes('docs-internal-guid') && !html.includes('google-docs')) {
    return false;
  }
  
  try {
    // Parse the HTML content
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');
    
    // Process links to preserve href attributes
    doc.querySelectorAll('a').forEach(anchor => {
      const href = anchor.getAttribute('href');
      if (href) {
        anchor.setAttribute('href', href);
      }
    });
    
    // Find all images and store their positions
    const imageElements = doc.querySelectorAll('img');
    const images: { element: HTMLImageElement; placeholder: string }[] = [];
    
    // Replace each image with a unique placeholder
    imageElements.forEach((img, index) => {
      const placeholder = `__IMAGE_${index}__`;
      images.push({ 
        element: img as HTMLImageElement, 
        placeholder 
      });
      
      // Replace the image with the placeholder text
      if (img.parentNode) {
        const textNode = doc.createTextNode(placeholder);
        img.parentNode.replaceChild(textNode, img);
      }
    });
    
    // Clean up Google Docs spans
    doc.querySelectorAll('span[style]').forEach(span => {
      if (span.textContent?.trim()) {
        const text = span.textContent;
        span.parentNode?.replaceChild(document.createTextNode(text), span);
      } else {
        span.remove();
      }
    });
    
    // Get the cleaned HTML with placeholders
    let content = doc.body.innerHTML;
    
    // Insert the content first
    editor.commands.setContent(content, false, {
      preserveWhitespace: true,
    });
    
    // Replace placeholders with actual images
    images.forEach(({ element, placeholder }) => {
      const src = element.src;
      if (!src) return;
      
      // Find the text node with our placeholder
      editor.state.doc.descendants((node, pos) => {
        if (node.isText && node.text?.includes(placeholder)) {
          editor.chain()
            .setTextSelection(pos)
            .deleteRange({ from: pos, to: pos + placeholder.length })
            .setImage({ src })
            .run();
        }
      });
    });
    
    return true;
  } finally {
    // No cleanup needed
  }
};

const handleRegularHtmlPaste = (editor: CoreEditor | null, html: string) => {
  if (!editor) return false;
  
  // Let TipTap handle HTML content with its built-in parser
  editor.chain()
    .focus()
    .insertContent(html, {
      parseOptions: {
        preserveWhitespace: true,
      },
    })
    .run();
  
  return true;
};

const handlePasteImage = (editor: CoreEditor | null, file: File) => {
  if (!editor) return;
  
  const reader = new FileReader();
  reader.onload = (e) => {
    if (typeof e.target?.result === 'string') {
      editor.chain()
        .focus()
        .setImage({ src: e.target.result })
        .run();
    }
  };
  reader.readAsDataURL(file);
};

const MenuBar = ({ editor }: MenuBarProps) => {
  if (!editor) return null;

  const toggleLink = () => {
    const previousUrl = editor.getAttributes('link').href;
    const url = window.prompt('URL', previousUrl);

    if (url === null) {
      return;
    }

    if (url === '') {
      editor.chain().focus().extendMarkRange('link').unsetLink().run();
      return;
    }

    editor.chain().focus().extendMarkRange('link').setLink({ href: url }).run();
  };

  const addImage = () => {
    const url = window.prompt('URL');
    if (url) {
      editor.chain().focus().setImage({ src: url }).run();
    }
  };

  return (
    <div className="border-b border-gray-200 p-2 flex gap-1 flex-wrap bg-white rounded-t-lg">
      <button
        onClick={() => editor.chain().focus().toggleBold().run()}
        disabled={!editor.can().chain().focus().toggleBold().run()}
        className={clsx(
          'p-2 rounded hover:bg-gray-100 transition-colors',
          { 'bg-gray-100': editor.isActive('bold') }
        )}
      >
        <Bold className="w-5 h-5" />
      </button>
      <button
        onClick={() => editor.chain().focus().toggleItalic().run()}
        disabled={!editor.can().chain().focus().toggleItalic().run()}
        className={clsx(
          'p-2 rounded hover:bg-gray-100 transition-colors',
          { 'bg-gray-100': editor.isActive('italic') }
        )}
      >
        <Italic className="w-5 h-5" />
      </button>
      <button
        onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}
        className={clsx(
          'p-2 rounded hover:bg-gray-100 transition-colors',
          { 'bg-gray-100': editor.isActive('heading', { level: 1 }) }
        )}
      >
        <Heading1 className="w-5 h-5" />
      </button>
      <button
        onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}
        className={clsx(
          'p-2 rounded hover:bg-gray-100 transition-colors',
          { 'bg-gray-100': editor.isActive('heading', { level: 2 }) }
        )}
      >
        <Heading2 className="w-5 h-5" />
      </button>
      <button
        onClick={() => editor.chain().focus().toggleBulletList().run()}
        className={clsx(
          'p-2 rounded hover:bg-gray-100 transition-colors',
          { 'bg-gray-100': editor.isActive('bulletList') }
        )}
      >
        <List className="w-5 h-5" />
      </button>
      <button
        onClick={() => editor.chain().focus().toggleOrderedList().run()}
        className={clsx(
          'p-2 rounded hover:bg-gray-100 transition-colors',
          { 'bg-gray-100': editor.isActive('orderedList') }
        )}
      >
        <ListOrdered className="w-5 h-5" />
      </button>
      <button
        onClick={() => editor.chain().focus().toggleTaskList().run()}
        className={clsx(
          'p-2 rounded hover:bg-gray-100 transition-colors',
          { 'bg-gray-100': editor.isActive('taskList') }
        )}
      >
        <CheckSquare className="w-5 h-5" />
      </button>
      <button
        onClick={() => editor.chain().focus().toggleBlockquote().run()}
        className={clsx(
          'p-2 rounded hover:bg-gray-100 transition-colors',
          { 'bg-gray-100': editor.isActive('blockquote') }
        )}
      >
        <Quote className="w-5 h-5" />
      </button>
      <button
        onClick={toggleLink}
        className={clsx(
          'p-2 rounded hover:bg-gray-100 transition-colors',
          { 'bg-gray-100': editor.isActive('link') }
        )}
      >
        <LinkIcon className="w-5 h-5" />
      </button>
      <button
        onClick={() => editor.chain().focus().toggleHighlight().run()}
        className={clsx(
          'p-2 rounded hover:bg-gray-100 transition-colors',
          { 'bg-gray-100': editor.isActive('highlight') }
        )}
      >
        <Highlighter className="w-5 h-5" />
      </button>
      <button
        onClick={addImage}
        className="p-2 rounded hover:bg-gray-100 transition-colors"
      >
        <ImageIcon className="w-5 h-5" />
      </button>
    </div>
  );
};

interface EditorProps {
  content: any;
  onUpdate: (content: any) => void;
}

export default function Editor({ content, onUpdate }: EditorProps) {
  const editor = useEditor({
    extensions: [
      StarterKit,
      Placeholder.configure({
        placeholder: 'Write something amazing...',
      }),
      Highlight,
      TaskList,
      TaskItem.configure({
        nested: true,
      }),
      Link.configure({
        openOnClick: true,
        HTMLAttributes: {
          class: 'text-blue-600 hover:text-blue-800 underline',
          rel: 'noopener noreferrer',
          target: '_blank'
        },
      }),
      Image.configure({
        HTMLAttributes: {
          class: 'rounded-lg max-w-full h-auto',
          draggable: 'false',
        },
      }),
    ],
    content: content || '',
    onUpdate: ({ editor }) => {
      onUpdate(editor.getJSON());
    },
    editorProps: {
      attributes: {
        class: 'prose prose-lg max-w-none focus:outline-none min-h-[200px] px-4 py-2',
      },
      handlePaste: (view, event) => {
        if (!event.clipboardData) return false;
        
        const html = event.clipboardData.getData('text/html');
        const text = event.clipboardData.getData('text/plain');
        const items = Array.from(event.clipboardData.items);
        
        // Try each paste handler in order
        if (items.some(item => item.type.startsWith('image')) && 
            handleDirectImagePaste(editor, items)) {
          return true;
        }
        
        if (text && handleImageUrlPaste(editor, text)) {
          return true;
        }
        
        if (html && handleGoogleDocsPaste(editor, html)) {
          return true;
        }
        
        if (html && handleRegularHtmlPaste(editor, html)) {
          return true;
        }

        return false;
      },
    },
  });

  return (
    <div className="border rounded-lg bg-white shadow-sm">
      <MenuBar editor={editor} />
      <EditorContent editor={editor} />
    </div>
  );
}