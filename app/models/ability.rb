class Ability
  include CanCan::Ability

  def initialize(user)
    # Define abilities for the passed in user here. For example:
    #
    #   user ||= User.new # guest user (not logged in)
    #   if user.admin?
    #     can :manage, :all
    #   else
    #     can :read, :all
    #   end
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, :published => true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/wiki/Defining-Abilities

    # Permissions for every user, even if not logged in
    can [:edit, :index, :filter, :change_via_script, :compare_contigs, :as_fasq], Contig
    can [:edit, :index, :filter, :show_species], Family
    can [:edit, :index, :show_species], HigherOrderTaxon
    can [:about, :overview, :impressum, :privacy_policy], :home
    can [:edit, :index, :filter, :xls], Individual
    can [:edit, :index, :filter], Isolate
    can [:filter], MarkerSequence
    can [:edit, :index, :filter], Order
    can :manage, PartialCon
    can [:edit, :index], PrimerRead
    can [:edit, :index, :filter, :show_individuals, :xls], Species
    can :manage, TxtUploader
    can :manage, :overview_diagram

    # Additional permissions for logged in users
    if user.present?
      can :manage, :all

      cannot :manage, User
      cannot :manage, Project
      cannot :manage, Responsibility
      cannot [:create, :destroy], MislabelAnalysis
      cannot [:create, :destroy], Mislabel

      can [:read, :search_taxa, :add_to_taxa], Project, id: user.project_ids

      # Additional permissions for guests
      if user.guest?
        cannot [:change_base, :change_left_clip, :change_right_clip], PrimerRead
        cannot [:create, :update, :destroy], :all
        can :edit, :all
      end

      # Additional permissions for administrators and supervisors
      if user.admin? || user.supervisor?
        can :manage, User
        can :manage, Project
        can :manage, Responsibility
        can :manage, MislabelAnalysis
        can :manage, Mislabel

        cannot [:create, :update, :destroy], User, role: 'admin' if user.supervisor?
      end

      can [:home, :show, :edit, :update, :destroy], User, id: user.id # User can see and edit own profile

      cannot :manage, ContigSearch
      can :create, ContigSearch
      can :manage, ContigSearch, user_id: user.id # Users can only edit their own searches

      cannot :manage, MarkerSequenceSearch
      can :create, MarkerSequenceSearch
      can :manage, MarkerSequenceSearch, user_id: user.id # Users can only edit their own searches

      if user.responsibilities.exists?(:name => "lab") # Restrictions for users in project "lab"
        cannot [:create, :update, :destroy], [Family, Species, Individual, Division, Order, TaxonomicClass, HigherOrderTaxon]
        can :edit, [Family, Species, Individual, Division, Order, TaxonomicClass, HigherOrderTaxon]
      elsif user.responsibilities.exists?(:name => 'taxonomy') # Restrictions for users in project "taxonomy"
        cannot [:create, :update, :destroy], [Alignment, Contig, Freezer, Isolate, Issue, Lab, LabRack, Marker,
                                              MarkerSequence, MicronicPlate, PartialCon, PlantPlate, Primer, PrimerRead, Shelf, Tissue]
        can :edit, [Alignment, Contig, Freezer, Isolate, Issue, Lab, LabRack, Marker, MarkerSequence, MicronicPlate,
                    PartialCon, PlantPlate, Primer, PrimerRead, Shelf, Tissue]
        cannot [:change_base, :change_left_clip, :change_right_clip], PrimerRead
        cannot :manage, ContigSearch
        cannot :manage, MarkerSequenceSearch
      end

      cannot :delete_all, ContigSearch unless user.responsibilities.exists?(name: 'delete_contigs') || user.admin? || user.supervisor?
    end
  end
end
