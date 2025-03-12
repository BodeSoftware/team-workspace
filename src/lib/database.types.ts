export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      documents: {
        Row: {
          id: string
          title: string
          content: Json | null
          workspace_id: string
          parent_id: string | null
          created_by: string
          created_at: string | null
          updated_at: string | null
        }
        Insert: {
          id?: string
          title: string
          content?: Json | null
          workspace_id: string
          parent_id?: string | null
          created_by: string
          created_at?: string | null
          updated_at?: string | null
        }
        Update: {
          id?: string
          title?: string
          content?: Json | null
          workspace_id?: string
          parent_id?: string | null
          created_by?: string
          created_at?: string | null
          updated_at?: string | null
        }
      }
    }
  }
}